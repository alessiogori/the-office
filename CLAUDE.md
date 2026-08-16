# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> Documentazione completa in [`docs/`](docs/README.md): guida introduttiva, catalogo dei
> ruoli, reference dei comandi, architettura, anime, testing.

## Cos'è questo repo

Un sistema multi-agente installabile in altri progetti: `agents/`, `catalog/`,
`shared-context/`, `setup.sh`, `AGENTS.md`, `GEMINI.md`. `setup.sh` compone un
team su misura e ne esporta un bundle autonomo, pronto da innestare altrove.

Non c'è codice applicativo: sono script bash, dati JSON e markdown. Il resto
(`docs/`, `examples/`, `traffic-data/`) è documentazione e dati di esempio.

## Comandi

```bash
./agents/launch.sh <agente>            # avvia Claude Code col prompt di ruolo
./agents/iterm.sh <agente|all>         # apre finestre iTerm2 dedicate (una per agente)
./agents/setstatus.sh <agente> <WORKING|IDLE|STANDBY> ["task"]
./agents/with-status.sh <agente> "<task>" -- <comando>   # wrap: WORKING → comando → IDLE
./agents/msg.sh <mittente> <destinatario> "<testo>"
./agents/ack.sh <msg-id> <agente>
./agents/qtask.sh <add|done|list> <agente> [...]
./agents/dashboard.sh                  # snapshot stato + code
./agents/live-dashboard.sh             # dashboard in refresh continuo
./agents/hire.sh [<ruolo> "<Nome>"]    # aggiunge una persona al team esistente

./setup.sh                             # wizard TUI: compone il team ed esporta
./setup.sh --config <f>                # non interattivo, esporta in exports/
./setup.sh --config <f> --target <d>   # installa direttamente in una directory
```

Gli id validi **non sono cablati da nessuna parte**: vengono da `shared-context/TEAM.json`. Ogni script valida contro il manifest e, se sbagli, ti stampa gli id disponibili.

### Test

```bash
git submodule update --init --recursive   # una volta, per bats-core
./tests/run.sh                            # tutta la suite
./tests/run.sh tests/team-lib.bats        # un solo file
```

I test girano su una `shared-context/` temporanea via `OFFICE_SHARED_DIR`: non toccano mai lo stato reale del repo. La suite del wizard genera progetti veri in directory temporanee, quindi è la più lenta.

## Architettura

### Coordinamento via filesystem

Gli agenti non comunicano direttamente. Tutto passa da `shared-context/`:

| File | Scrittore | Formato |
|------|-----------|---------|
| `TEAM.json` | `setup.sh`, `hire.sh` | il team: chi c'è, con che ruolo, in quale cartella |
| `AGENT-STATUS.json` | `setstatus.sh` | mappa `agente → {status, task, ts}` |
| `MSG-LOG.jsonl` | `msg.sh`, `ack.sh` | append-only, eventi `SENT` / `ACK` sulla stessa timeline |
| `inbox/<agente>/` | `msg.sh` | messaggi recapitati |
| `queues/<agente>.json` | `qtask.sh` | array di task pendenti |

Regole invarianti: `MSG-LOG.jsonl` non viene **mai** riscritto, solo appeso. Ogni altro file in `shared-context/` si scrive su un temporaneo nella stessa directory e si promuove con `os.replace`: gli altri agenti stanno leggendo mentre tu scrivi, e non devono mai vedere un file a metà. La mutazione JSON passa da `python3` (dipendenza implicita, mai `jq`).

`msg.sh`/`ack.sh` recapitano il messaggio nella finestra iTerm2 dell'agente via AppleScript, cercandola per nome sessione — il nome viene dal manifest, ed è `iterm.sh` a impostarlo, quindi le tre parti restano allineate da sole. `OFFICE_NO_ITERM=1` salta la consegna: il messaggio resta comunque su log e inbox.

## Catalogo e manifest

Due file con ruoli diversi, ed è la distinzione portante del sistema:

- **`catalog/roles.json`** — il **possibile**: 36 figure con missione, confini `can`/`cannot`, collaboratori, log di ruolo e `tension` (contro chi spinge e su cosa: è ciò che rende operativa la regola "i disaccordi sono un bene"). Viene distribuito ai progetti generati, perché senza catalogo `hire.sh` non avrebbe da cosa scegliere.
- **`shared-context/TEAM.json`** — l'**attuale**: chi c'è davvero in questo progetto.

Due librerie separate li servono, e la divisione è per frequenza d'uso:

- **`agents/lib/team.sh`** — risponde a "chi c'è nel team". La carica ogni script a ogni comando: `team_ids`, `team_validate`, `team_get <id> <campo>`, `team_coordinators`.
- **`agents/lib/roster.sh`** — risponde a "chi potrebbe esserci". La caricano solo `setup.sh` e `hire.sh`: accesso al catalogo e `roster_generate_person`, che crea la cartella di una persona.
- **`agents/lib/tui.sh`** — le schermate `gum`. Solo sui percorsi interattivi: ogni comando ha una forma ad argomenti che funziona senza gum.

`catalog/souls/<slug>.md` contiene le sei anime scritte a mano. Per le altre 30 figure il file non esiste, ed è previsto: `SOUL.md` viene scritto al primo avvio dell'agente, seguendo `catalog/SOUL-AUTHORING.md` e il `ROLE-BRIEF.md` della persona, così nasce calato sul progetto reale invece che generico.

Nei file del catalogo `__AGENT_NAME__`, `__AGENT_ID__` e `__ROLE_LABEL__` sono segnaposto sostituiti alla generazione. Gli altri agenti sono citati per ruolo (`<tester>`, "il Product Manager") e mai per nome: i nomi cambiano da progetto a progetto.

### Aggiungere un ruolo al catalogo

Una voce in `catalog/roles.json` con tutti i campi obbligatori. `tests/catalog.bats` verifica che non manchi nulla e che i `collaborates` puntino a slug esistenti. Non serve toccare codice: `setup.sh` e `hire.sh` la vedono subito.

### Hook di stato automatico

`agents/claude-hooks/pre-tool.sh` (PreToolUse) e `stop.sh` (Stop) chiamano `setstatus.sh` per marcare l'agente WORKING/IDLE senza intervento manuale. Richiedono `OFFICE_AGENT=<agente>` nell'ambiente della sessione; senza quella var escono silenziosamente. Non sono registrati in `.claude/settings.local.json` — vanno aggiunti a mano al `settings.json` del progetto che li usa.

### Configurazioni parallele

`CLAUDE.md`, `AGENTS.md` (Cursor/Copilot/Windsurf/Codex) e `GEMINI.md` descrivono lo **stesso** sistema per tool diversi. Nei progetti generati i tre file sono prodotti da `generate_agent_docs` in `setup.sh` a partire dal manifest, quindi restano allineati da soli. In questo repo sono scritti a mano: una modifica ai ruoli o ai confini va replicata in tutti e tre.

---

# Il sistema multi-agente

## Il team di questo repo

Sei persone, descritte in `shared-context/TEAM.json`. Non è un elenco fisso del sistema: è il team *di questo progetto*, e altri progetti generati dal wizard ne hanno di diversi.

| Persona | Ruolo | Cartella | Log |
|---------|-------|----------|-----|
| Alessio | CEO / Founder | `agents/alessio/` | — |
| Stefano | Engineer (full-stack) | `agents/stefano/` | `BUILD-LOG.md` |
| Walter | Product Manager | `agents/walter/` | `BACKLOG.md` |
| Veronica | Marketing & Documentation | `agents/veronica/` | `CONTENT-CALENDAR.md`, `DOC-QUEUE.md` |
| Alessandra | UI/UX Specialist | `agents/alessandra/` | `UI-REVIEW-LOG.md` |
| Marwen | Tester / QA | `agents/marwen/` | `BUG-LOG.md`, `TEST-CHECKLIST.md` |

Missione, confini `can`/`cannot` e attrito di ogni ruolo stanno in `catalog/roles.json` sotto lo slug corrispondente (`ceo`, `engineer`, `product`, `marketing`, `uiux`, `tester`), e nell'`IDENTITY.md` della persona.

Le cartelle sono nominate per **persona**, non per ruolo: due sviluppatori nello stesso team devono poter coesistere.

## Pipeline

```
Walter (spec) → Stefano (build) → Alessandra (UI/UX) → Marwen (QA) → produzione
```

Niente va in produzione senza passare da Alessandra e Marwen. In un progetto con un team diverso la pipeline cambia di conseguenza: quello che non cambia è che chi costruisce non è chi approva.

## File per agente

Ogni cartella `agents/<persona>/` contiene:

| File | Origine | Cosa contiene |
|------|---------|---------------|
| `SOUL.md` | catalogo, o scritto al primo avvio | come pensa, cosa rifiuta |
| `IDENTITY.md` | generato dai dati del ruolo | confini di accesso, comandi già compilati con il suo id |
| `HEARTBEAT.md` | template | stato corrente, aggiornato a fine sessione |
| `ROLE-BRIEF.md` | dati del catalogo | la fonte per scrivere l'anima |
| log di ruolo | template | secondo il campo `log` del manifest, se presente |

## Shared Context
Letto da tutti gli agenti: `shared-context/THESIS.md` (visione), `ROADMAP.md`, `BRAND-GUIDE.md` (voce e tono).

## Session Tracking
Un file al giorno: `docs/sessions/YYYY-MM-DD-session.md`. Ogni agente aggiorna la propria sezione, mai quelle degli altri: il file è condiviso tra sessioni parallele.

## Rules
1. Ogni agente resta nel suo dominio. I confini di `IDENTITY.md` non si attraversano.
2. I disaccordi sono un bene. Ogni ruolo ha un `tension` dichiarato nel catalogo ed è tenuto a usarlo.
3. Ogni agente legge SOUL.md e IDENTITY.md all'inizio di ogni sessione. Se SOUL.md manca, lo scrive.
4. HEARTBEAT.md va aggiornato a fine sessione.
5. In caso di dubbio, `shared-context/THESIS.md`.

## Slash Commands

Definiti in `.claude/commands/`. Valgono solo dentro una sessione Claude Code già avviata; per aprire un terminale nuovo per un agente usa `./agents/launch.sh <agente>` o `./agents/iterm.sh <agente>`.

| Comando | Cosa fa |
|---------|---------|
| `/startup [agente]` | Senza argomento elenca il team da `TEAM.json`; con argomento carica quella persona (accetta id o nome) |
| `/ceo` `/engineer` `/product` `/marketing` `/uiux` `/tester-agent` | Caricano direttamente il ruolo |
| `/session` | Aggiorna la tua sezione in `docs/sessions/<data>-session.md` |
| `/wrap-up` | Chiusura: HEARTBEAT, log di ruolo, sessione, ACK inbox, stato STANDBY |

Ogni comando di ruolo segue lo stesso schema: SOUL → IDENTITY → HEARTBEAT → log di ruolo → shared-context → inbox → coda → `setstatus.sh <agente> IDLE`, poi un solo messaggio di ready e stop. Se aggiungi o rinomini un agente vanno aggiornati insieme: il comando, `src/agents.ts`, la validazione in ogni script bash, `AGENTS.md` e `GEMINI.md`.

`/wrap-up` e `/session` scrivono su un file condiviso da più sessioni: modificano **solo** la sezione dell'agente corrente, mai il file intero.

Ogni comando di ruolo comincia con lo stesso passo 0: se `SOUL.md` manca, viene scritto seguendo `agents/_authoring/SOUL-AUTHORING.md` prima di procedere.

Se aggiungi o rinomini una persona vanno aggiornati insieme: `TEAM.json`, la cartella in `agents/`, e — solo se vuoi un comando dedicato — un file in `.claude/commands/`. Gli script non richiedono nulla: leggono il manifest.
