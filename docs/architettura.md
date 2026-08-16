# Architettura

Come è fatto il sistema, e perché è fatto così. Leggilo se devi modificarlo, non solo usarlo.

## Il problema che risolve

Un team di agenti AI ha bisogno di due cose che di solito mancano: **confini** e **memoria condivisa**. Senza confini ogni agente fa tutto, e la separazione dei ruoli diventa teatro. Senza memoria condivisa ogni sessione riparte da zero.

Il sistema risolve entrambi con dei file. Gli agenti non si parlano: leggono e scrivono in `shared-context/`, e ognuno ha un `IDENTITY.md` che dice cosa può toccare.

## Catalogo e manifest

La distinzione portante.

**`catalog/roles.json` — il possibile.** 36 figure con missione, `can`, `cannot`, `collaborates`, log di ruolo e `tension`. Non descrive nessun team in particolare: descrive cosa un team può contenere. Viene distribuito ai progetti generati, perché `hire.sh` deve avere da cosa scegliere.

**`shared-context/TEAM.json` — l'attuale.** Chi c'è davvero in questo progetto:

```json
{
  "version": 1,
  "team": [
    { "id": "marco", "name": "Marco", "role": "backend",
      "label": "Backend Engineer", "folder": "agents/marco",
      "log": "BUILD-LOG.md", "color": "#4a90e2", "coordinator": false }
  ]
}
```

`id` è la chiave usata ovunque: `AGENT-STATUS.json`, `inbox/<id>/`, `queues/<id>.json`, ogni comando. È il nome della persona normalizzato — minuscolo, senza accenti né spazi.

**Perché l'identità viene dal nome e non dal ruolo.** Se l'id fosse lo slug del ruolo, due backend engineer nello stesso team sarebbero impossibili, o diventerebbero `backend-1` e `backend-2`. Un messaggio come `./agents/msg.sh backend-1 qa-2 "..."` perde esattamente l'effetto squadra che è il senso del progetto.

## Le tre librerie

Divise per **frequenza d'uso**, non per argomento.

### `agents/lib/team.sh` — chi c'è

La carica ogni script, a ogni comando. Deve restare piccola e senza dipendenze.

| Funzione | Cosa fa |
|----------|---------|
| `team_manifest_path` | Percorso del manifest, rispettando `OFFICE_TEAM_FILE` e `OFFICE_SHARED_DIR` |
| `team_require_manifest` | Esce con codice 2 e messaggio leggibile se manca o è corrotto |
| `team_ids` | Un id per riga, nell'ordine del manifest |
| `team_validate <id>` | 0 o 1; in errore stampa gli id validi |
| `team_get <id> <campo>` | `name`, `role`, `label`, `folder`, `log`, `color`, `coordinator` |
| `team_coordinators` | Gli id con `coordinator: true` |

### `agents/lib/roster.sh` — chi potrebbe esserci

La caricano solo `setup.sh` e `hire.sh`. Conosce il catalogo e sa costruire una cartella persona.

| Funzione | Cosa fa |
|----------|---------|
| `roster_slugs` | Tutti gli slug del catalogo |
| `roster_coordinator_slugs` | Solo i ruoli di coordinamento |
| `roster_role_get <slug> <campo>` | Un campo del ruolo; le liste una voce per riga |
| `roster_choices` | Righe `Categoria · Label<TAB>slug` per `gum filter` |
| `roster_id_from_name <nome>` | Normalizzazione: `Niccolò` → `niccolo` |
| `roster_next_color <team.json>` | Un colore non ancora usato dal team |
| `roster_generate_person <slug> <nome> <id> <dir> <team.json>` | Crea la cartella con i suoi file |

### `agents/lib/tui.sh` — le schermate

Solo i percorsi interattivi. **Ogni comando ha una forma ad argomenti che non la usa**: è ciò che rende il sistema testabile senza pilotare una TUI, e utilizzabile su una macchina senza `gum`.

## Coordinamento via filesystem

| File | Chi scrive | Formato |
|------|-----------|---------|
| `TEAM.json` | `setup.sh`, `hire.sh` | il team |
| `AGENT-STATUS.json` | `setstatus.sh` | `id → {status, task, ts}` |
| `MSG-LOG.jsonl` | `msg.sh`, `ack.sh` | append-only, eventi `SENT` e `ACK` |
| `inbox/<id>/` | `msg.sh` | un file markdown per messaggio |
| `queues/<id>.json` | `qtask.sh` | array di task pendenti |

### Due invarianti

**`MSG-LOG.jsonl` non viene mai riscritto.** `SENT` e `ACK` sono eventi separati sulla stessa timeline, e la storia non si modifica. Puoi interrogarlo con `grep` o `jq` sapendo che nessuna riga è mai cambiata.

**Ogni altra scrittura è atomica.** File temporaneo nella stessa directory, poi `os.replace`. Gli altri agenti stanno leggendo mentre tu scrivi: un `TEAM.json` letto a metà romperebbe ogni script simultaneamente. `os.replace` sullo stesso filesystem è atomico, quindi un lettore vede la versione vecchia o quella nuova, mai una via di mezzo.

### Perché `python3` e non `jq`

`jq` è lo strumento giusto per il lavoro, ma è una dipendenza in più da installare. `python3` c'è già su ogni macOS e ogni Linux moderno, e gli script lo usavano comunque per l'escaping JSON dei messaggi. Una dipendenza implicita già pagata batte una esplicita nuova.

Un dettaglio che costa un'ora se non lo sai: `python3 -` legge **il programma** da stdin, quindi non puoi anche passargli dati via pipe. I dati passano da `argv`.

## Il ciclo di vita di un agente

```
setup.sh / hire.sh
    │
    ├── roster_generate_person
    │     ├── IDENTITY.md      generato dai dati del ruolo
    │     ├── HEARTBEAT.md     da template
    │     ├── ROLE-BRIEF.md    i dati del ruolo, leggibili
    │     ├── <LOG>.md         se il ruolo ne prevede uno
    │     └── SOUL.md          solo se il catalogo ne ha una scritta
    │
    ├── voce in TEAM.json      con id, folder, colore
    └── inbox/ e queues/
              │
              ▼
       launch.sh <id>
              │
              ├── SOUL.md manca? → viene scritto ora, dal brief
              │                     e dal contesto del progetto
              └── l'agente legge, si ferma, aspetta un ordine
```

**Perché `IDENTITY.md` è generato e `SOUL.md` no.** L'identità definisce i confini di accesso: deve essere prevedibile, uguale a parità di ruolo, e verificabile. Se fosse scritta a mano ogni copia divergerebbe. L'anima descrive come pensa un agente: se fosse generata da un template, tutti gli agenti suonerebbero uguali, e si perderebbe la cosa che distingue questo sistema da un elenco di prompt.

## Il flusso dei messaggi

```
msg.sh marco davide "Schema pronto"
    │
    ├── team_validate su entrambi        ← id fuori dal manifest = errore
    ├── team_get per i nomi visualizzati
    ├── append SENT su MSG-LOG.jsonl
    ├── scrive inbox/davide/<id>.md
    └── AppleScript → finestra iTerm2 di "Davide"
            │
            └── saltato se OFFICE_NO_ITERM o osascript assente:
                il messaggio resta comunque su log e inbox
```

La finestra si trova per **nome sessione**, che `iterm.sh` imposta leggendolo dal manifest. Le tre parti — chi apre la finestra, chi manda, chi conferma — leggono tutte la stessa sorgente, quindi restano allineate da sole. Prima del manifest c'erano tre mappe cablate da tenere in sincronia a mano.

## Variabili d'ambiente

| Variabile | Effetto |
|-----------|---------|
| `OFFICE_SHARED_DIR` | Sposta `shared-context/`. È il meccanismo con cui i test si isolano, ed è rispettata anche dal watcher Rust dell'overlay |
| `OFFICE_TEAM_FILE` | Sposta il solo `TEAM.json` |
| `OFFICE_CATALOG_FILE` | Sposta `catalog/roles.json` |
| `OFFICE_AGENTS_DIR` | Dove `hire.sh` crea la cartella persona |
| `OFFICE_NO_ITERM` | Salta la consegna AppleScript |
| `OFFICE_ASSUME_NO_GUM` | Simula l'assenza di gum, per i test del preflight |
| `OFFICE_AGENT` | Attiva gli hook di stato automatico |

## Vincoli di compatibilità

**bash 3.2.** macOS ne ha uno del 2007 di serie, e il sistema deve funzionarci. Niente array associativi (`declare -A`), niente `${var^^}`, niente `mapfile`. Il case si cambia con `tr`, le liste si scorrono con `while read`.

Questo vincolo è costato la riscrittura di `iterm.sh`, che era zsh con `typeset -A`, e la correzione di un `${FROM_NAME,,}` in `ack.sh` che su macOS non ha mai funzionato.

**Gestione degli errori.** Ogni errore utente esce con codice 2 e un messaggio in italiano su stderr. Lo stderr di `python3` è soppresso: un traceback non è un messaggio d'errore per chi usa lo strumento.

## Hook di stato automatico

`agents/claude-hooks/pre-tool.sh` (PreToolUse) e `stop.sh` (Stop) chiamano `setstatus.sh` per marcare l'agente WORKING/IDLE senza intervento manuale. Richiedono `OFFICE_AGENT=<id>` nell'ambiente; senza quella variabile escono in silenzio. Vanno registrati a mano nel `settings.json` del progetto.

## office-overlay

L'app Tauri che mostra gli agenti come stanza pixel-art **non** viene distribuita da `setup.sh`: vive solo in questo repo. Legge `AGENT-STATUS.json` e `MSG-LOG.jsonl` con un watcher Rust (`notify`) e emette eventi al frontend Pixi.js.

Oggi ha sei agenti cablati in `src/agents.ts` e sei scrivanie fisse in `room.ts`. Continua a funzionare perché gli id di questo repo non sono cambiati con la migrazione. Fargli leggere `TEAM.json` e disporre N scrivanie è il miglioramento naturale successivo, ed è fuori dalla portata del lavoro attuale.
