# TUI Team Setup — Design

**Data:** 2026-08-16
**Branch:** `feat/tui-team-setup`
**Stato:** approvato in brainstorming, da implementare

## Problema

`setup.sh` installa sempre lo stesso team: sei ruoli fissi, cablati in una quindicina di punti dello script. Un progetto che ha bisogno di due backend e nessun marketing non è esprimibile.

Il vincolo non è solo nel wizard. I sei ruoli sono cablati anche nella validazione `case` di `setstatus.sh`, `qtask.sh`, `msg.sh`, `ack.sh`, `iterm.sh`, `launch.sh`, `dashboard.sh` e `live-dashboard.sh`. Rendere il team variabile significa spostare la conoscenza del team dal codice a un manifest, e far leggere quel manifest a tutti.

## Obiettivo

Un wizard TUI che chiede quante persone servono e che ruolo ha ciascuna, scegliendo da un catalogo di 34 figure, con almeno un ruolo di coordinamento obbligatorio. Il team risultante funziona end-to-end: messaggi, status, code, dashboard e avvio terminali operano sul team scelto, non su sei nomi cablati. Dopo il setup, `agents/hire.sh` aggiunge una persona al team senza rigenerare il progetto.

## Decisioni prese

| Decisione | Scelta | Perché |
|---|---|---|
| Portata | Manifest + script runtime | Un team variabile che gli script rifiutano non è un team variabile |
| Tecnologia TUI | `gum` (charmbracelet) | Multi-select, filtri e stile pronti; il codice del wizard resta sul flusso |
| gum assente | Offri di installarlo, poi esci | Un percorso solo da mantenere; un fallback testuale è il ramo che nessuno testa |
| Anime dei ruoli nuovi | Scritte a runtime al primo avvio | Setup offline e a costo zero; l'anima nasce calata nel progetto reale |
| Identità | ID dal nome della persona | I duplicati funzionano senza casi speciali; è la convenzione già in uso negli script |
| Migrazione | Anche questo repo | Il repo deve esercitare il codice che distribuisce |
| Runtime | Manifest + libreria bash condivisa | Le copie divergenti degli script sono il vero costo di manutenzione |
| Test | bats-core come submodule | Un repo che distribuisce script deve poterli verificare; il submodule evita installazioni manuali |
| Team dopo il setup | `agents/hire.sh` | Un team cambia: assumere che si decida una volta sola è la premessa sbagliata |

## Modello dati

Tre artefatti con responsabilità distinte: il catalogo descrive il **possibile**, il manifest descrive l'**attuale**, il brief rende una persona **autonoma**.

### `catalog/roles.json` — il possibile

Viene copiato anche nel progetto generato: senza catalogo, `hire.sh` non avrebbe da cosa scegliere. È un solo file JSON, e distribuirlo è la differenza tra un team che può crescere e uno congelato al giorno del setup. Quello che **non** viene distribuito è `catalog/souls/`, di cui il progetto riceve solo le anime dei ruoli effettivamente scelti.

Una voce per figura:

```json
{
  "slug": "backend",
  "label": "Backend Engineer",
  "category": "Engineering",
  "coordinator": false,
  "mission": "API, business logic e persistenza. Il contratto verso il client è sacro.",
  "can": [
    "Leggere e scrivere codice server, migrazioni, test di integrazione",
    "Definire lo schema dati insieme al Database Specialist"
  ],
  "cannot": [
    "Modificare il frontend",
    "Cambiare le priorità di roadmap"
  ],
  "collaborates": ["frontend", "qa", "devops"],
  "log": "BUILD-LOG.md",
  "logTemplate": "build-log",
  "tension": "Spinge contro il PM quando una spec nasconde un cambio di schema non dichiarato"
}
```

`tension` non è decorativo. La regola 2 del sistema dice che i disaccordi sono un bene; senza un attrito dichiarato per ruolo, quella regola non ha appigli e ogni agente diventa un sì-uomo. È un campo obbligatorio.

`log` può essere `null`: il CEO non ha un log dedicato e usa l'HEARTBEAT. In quel caso non viene creato alcun file.

### `catalog/souls/<slug>.md` — le anime scritte

Esistono per i sei ruoli attuali (`ceo`, `engineer`, `product`, `marketing`, `uiux`, `tester`), migrati dai `SOUL.md` esistenti. Per le altre 28 figure il file è assente, e va bene così: l'anima nasce a runtime.

### `shared-context/TEAM.json` — l'attuale

Generato dal wizard nel progetto di destinazione, e presente anche in questo repo.

```json
{
  "version": 1,
  "team": [
    {
      "id": "alessio",
      "name": "Alessio",
      "role": "ceo",
      "label": "CEO / Founder",
      "folder": "agents/alessio",
      "log": null,
      "color": "#f5b400",
      "coordinator": true
    }
  ]
}
```

`id` è il nome in lowercase, senza spazi né accenti. È la chiave usata da `AGENT-STATUS.json`, `inbox/<id>/`, `queues/<id>.json` e da ogni script.

`color` serve a `iterm.sh` per il colore di sfondo della finestra, e in futuro all'overlay.

### `agents/<persona>/ROLE-BRIEF.md` — l'autonomia

I dati del ruolo dal catalogo, in forma leggibile, dentro la cartella della persona. È la fonte da cui viene scritta l'anima al primo avvio, e ciò che permette a un umano di capire i confini di un agente aprendo una cartella sola invece di cercare uno slug nel catalogo.

## Runtime: `agents/lib/team.sh`

Circa 80 righe, sourceata da tutti gli script. Il parsing usa `python3`, che gli script già usano per mutare `AGENT-STATUS.json` e le code: nessuna dipendenza nuova, niente `jq`.

```bash
team_require_manifest        # verifica esistenza e validità; exit 2 con messaggio se fallisce
team_ids                     # elenco degli id, uno per riga
team_validate <id>           # exit 0/1; in errore stampa gli id validi
team_get <id> <campo>        # name | role | label | folder | log | color | coordinator
team_coordinators            # id di chi ha coordinator=true
```

### Gestione degli errori

Se `TEAM.json` manca o non parsa, ogni script esce con codice 2 e un messaggio che indica il file e l'azione:

```
Errore: shared-context/TEAM.json non trovato.
Questo progetto non ha un team configurato. Lancia ./setup.sh per crearlo.
```

Un traceback Python addosso all'utente non è un messaggio d'errore. Lo stderr di `python3` viene soppresso e sostituito.

### Script da migrare

| Script | Cosa cambia |
|---|---|
| `setstatus.sh` | `case` di validazione → `team_validate` |
| `qtask.sh` | `case` di validazione → `team_validate` |
| `msg.sh` | `resolve_name()` → `team_get <id> name`; validazione mittente/destinatario |
| `ack.sh` | come `msg.sh` |
| `launch.sh` | ramo per agente → prompt costruito da `folder` e `name` |
| `iterm.sh` | mappe `BG`/`NAME`/`ROLE` cablate → `team_get` su `color`, `name`, `label` |
| `dashboard.sh` | elenco fisso → `team_ids` |
| `live-dashboard.sh` | come `dashboard.sh` |
| `with-status.sh` | nessun cambio diretto: delega a `setstatus.sh` |

`setstatus.sh` inizializza `AGENT-STATUS.json` con gli agenti presenti in `TEAM.json` invece che con la lista fissa.

## Il catalogo: 34 figure

Almeno una figura di coordinamento è obbligatoria ed è sempre la persona 1. Le sei attuali sono marcate ●.

### Coordinamento (`coordinator: true`)

| slug | label | log |
|---|---|---|
| `ceo` ● | CEO / Founder | — |
| `pm` | Project Manager | `PLAN.md` |
| `tech-lead` | Engineering Manager / Tech Lead | `TECH-DECISIONS.md` |
| `delivery-lead` | Delivery Lead / Scrum Master | `BLOCKERS.md` |
| `chief-of-staff` | Chief of Staff | `COORD-LOG.md` |

### Prodotto e ricerca

| slug | label | log |
|---|---|---|
| `product` ● | Product Manager | `BACKLOG.md` |
| `user-research` | User Researcher | `RESEARCH-LOG.md` |
| `market-research` | Market & Competitor Researcher | `MARKET-LOG.md` |
| `business-analyst` | Business Analyst | `REQUIREMENTS.md` |
| `data-analyst` | Data Analyst | `METRICS-LOG.md` |

### Design

| slug | label | log |
|---|---|---|
| `uiux` ● | UI/UX Specialist | `UI-REVIEW-LOG.md` |
| `graphic` | Graphic / Brand Designer | `DESIGN-LOG.md` |
| `ux-writer` | UX Writer / Content Designer | `COPY-LOG.md` |
| `motion` | Motion & Video Designer | `MOTION-LOG.md` |

### Engineering

| slug | label | log |
|---|---|---|
| `engineer` ● | Engineer (full-stack) | `BUILD-LOG.md` |
| `backend` | Backend Engineer | `BUILD-LOG.md` |
| `frontend` | Frontend Engineer | `BUILD-LOG.md` |
| `mobile` | Mobile Engineer | `BUILD-LOG.md` |
| `devops` | DevOps / SRE | `OPS-LOG.md` |
| `data-engineer` | Data Engineer | `PIPELINE-LOG.md` |
| `ml-engineer` | ML / AI Engineer | `MODEL-LOG.md` |
| `architect` | Solution Architect | `ADR-LOG.md` |
| `dba` | Database Specialist | `SCHEMA-LOG.md` |

### Qualità e sicurezza

| slug | label | log |
|---|---|---|
| `tester` ● | Tester / QA | `BUG-LOG.md` |
| `automation` | Automation & Performance Engineer | `PERF-LOG.md` |
| `security` | Security Engineer / AppSec | `SECURITY-LOG.md` |
| `a11y` | Accessibility Specialist | `A11Y-LOG.md` |

### Go-to-market

| slug | label | log |
|---|---|---|
| `marketing` ● | Marketing & Documentation | `CONTENT-CALENDAR.md` |
| `copywriter` | Content Writer / Copywriter | `CONTENT-LOG.md` |
| `seo` | SEO Specialist | `SEO-LOG.md` |
| `social` | Social Media Manager | `SOCIAL-CALENDAR.md` |
| `sales` | Sales / Business Development | `PIPELINE.md` |
| `support` | Customer Support Lead | `SUPPORT-LOG.md` |

### Operations

| slug | label | log |
|---|---|---|
| `tech-writer` | Technical Writer | `DOC-QUEUE.md` |
| `legal` | Legal & Compliance | `COMPLIANCE-LOG.md` |
| `finance` | Finance / Pricing Analyst | `FINANCE-LOG.md` |

I `logTemplate` distinti sono cinque: `build-log`, `backlog`, `calendar`, `review-log`, `bug-log`. I log che non rientrano usano un template generico a voci datate.

## Il wizard

`setup.sh` viene riscritto attorno a questo flusso.

**0. Preflight.** Verifica `gum`. Se manca, questa sola schermata usa `read` — non c'è alternativa — rileva il gestore di pacchetti disponibile (`brew`, `apt`, `go`) e propone il comando. Se l'utente accetta, installa e prosegue; se rifiuta, esce stampando le istruzioni.

**1. Progetto.** `gum input` per directory target, nome progetto, descrizione, tech stack, brand. Invariato rispetto a oggi.

**2. Dimensione.** `gum input` numerico, validato 1–12. Oltre i 12 il sistema non regge: sono dodici terminali aperti.

**3. Coordinamento.** `gum choose` sui cinque ruoli con `coordinator: true`. Schermata separata e non saltabile: il vincolo è un passo del flusso, non una regola nascosta nella validazione.

**4. Ruoli restanti.** Per ogni slot da 2 a N, `gum filter` sul catalogo con ricerca fuzzy e voci prefissate dalla categoria (`Engineering · Backend Engineer`). Uno slot alla volta invece di una multi-selezione: i duplicati funzionano senza casi speciali, e con 34 voci la ricerca incrementale batte lo scorrimento.

**5. Nomi.** `gum input` precompilato con un nome suggerito da un pool. Le collisioni sono rifiutate con un messaggio, non risolte in silenzio con un suffisso numerico.

**6. Conferma.** Tabella persona/ruolo/cartella e `gum confirm`. Nessun file viene scritto prima di questo sì.

### Modalità non interattiva

```bash
./setup.sh --config team.json     # salta la TUI, legge le scelte dal file
./setup.sh --save-config out.json # esporta le scelte fatte a mano
```

Serve a due cose che valgono più della comodità: rende il wizard testabile end-to-end senza pilotare una TUI, e rende i setup riproducibili tra progetti.

## Generazione

Per ogni persona il wizard scrive in `agents/<id>/`:

| File | Origine |
|---|---|
| `IDENTITY.md` | Generato dai dati del catalogo: nome, ruolo, CAN/CANNOT, collaboratori, attrito dichiarato, comandi `msg.sh` già compilati con il suo id e i destinatari reali del team |
| `HEARTBEAT.md` | Template, sezioni vuote |
| il log di ruolo | Da `logTemplate`; nessun file se `log` è `null` |
| `ROLE-BRIEF.md` | I dati del ruolo in forma leggibile |
| `SOUL.md` | Da `catalog/souls/<slug>.md` con i nomi sostituiti, **solo se esiste** |

`IDENTITY.md` è puramente derivato: nessuna creatività, nessuna variabilità. È il file che definisce i confini di accesso, e i confini devono essere prevedibili.

Nel progetto finisce anche `agents/_authoring/SOUL-AUTHORING.md`: le regole per scrivere un'anima in questo sistema — sezioni attese, lunghezza, l'obbligo di contenere rifiuti espliciti e non solo valori — con due delle sei anime esistenti come riferimento di stile.

## Anime a runtime

I comandi di ruolo guadagnano un passo iniziale. Se `agents/<id>/SOUL.md` manca:

1. Leggi `ROLE-BRIEF.md`, `agents/_authoring/SOUL-AUTHORING.md`, `shared-context/THESIS.md`, `shared-context/BRAND-GUIDE.md`
2. Scrivi `SOUL.md` seguendo le regole di authoring, calandolo su questo progetto specifico
3. Dichiara all'utente che l'anima è stata appena forgiata e dove si trova
4. Prosegui con la normale procedura di avvio

L'anima nasce dentro il progetto reale invece che generica: è il vantaggio del farlo a runtime, oltre al costo zero al momento del setup.

## Aggiungere un profilo a team esistente

`setup.sh` serve una volta sola, alla nascita del progetto. Un team però cambia dopo: `./agents/hire.sh` aggiunge una persona a un team già configurato, riusando le stesse schermate e lo stesso codice di generazione del wizard.

```bash
./agents/hire.sh                      # interattivo: ruolo dal catalogo, poi nome
./agents/hire.sh <ruolo> "<Nome>"     # diretto, per script e test
```

Il flusso interattivo è il passo 4 e il passo 5 del wizard, non una loro copia: `gum filter` sul catalogo, poi `gum input` per il nome, poi conferma.

Le funzioni condivise da wizard e `hire.sh` — scelta del ruolo, scelta del nome, generazione della cartella persona — stanno in una libreria separata, `agents/lib/roster.sh`, distribuita insieme al catalogo. La divisione è per responsabilità: `team.sh` risponde a "chi c'è nel team" e la usano tutti gli script a ogni comando; `roster.sh` risponde a "chi potrebbe esserci" e serve solo al setup e alle assunzioni. Tenerle separate evita che `msg.sh` carichi il codice delle schermate gum per mandare un messaggio.

La forma con argomenti non usa `gum`: il preflight scatta solo sul percorso interattivo, così assumere resta possibile su una macchina senza gum e dentro i test.

Cosa fa, in ordine:

1. Valida che il ruolo esista nel catalogo e che l'id derivato dal nome non sia già nel team
2. Crea `agents/<id>/` con gli stessi cinque file della generazione iniziale
3. Aggiunge la voce a `shared-context/TEAM.json`, assegnando un `color` non ancora usato dal team
4. Registra la persona in `AGENT-STATUS.json` come `STANDBY` e crea `inbox/<id>/` e `queues/<id>.json`
5. Stampa i due passi che restano all'umano: aprire il terminale con `./agents/iterm.sh <id>` e avvisare gli altri agenti

**Atomicità.** I passi 2, 3 e 4 toccano file che gli altri agenti stanno leggendo. Le scritture avvengono su file temporanei nella stessa directory e vengono promosse con `mv`, che su uno stesso filesystem è atomico: nessun agente legge mai un `TEAM.json` a metà. Se un passo fallisce, i precedenti vengono annullati e il team resta come prima.

**Il catalogo non basta mai.** Se serve una figura che le 34 non coprono, si aggiunge una voce a `catalog/roles.json` e `hire.sh` la vede subito. Il file ha uno schema documentato e un test che ne verifica i campi obbligatori, quindi estenderlo è un'operazione sicura e non richiede toccare codice.

Rimuovere una persona resta fuori portata: cancellare storia (log, inbox, messaggi inviati) è una decisione che merita un design suo, non un `rm -rf` dentro uno script.

## Migrazione di questo repo

- `git mv` delle sei cartelle da ruolo a persona: `agents/ceo` → `agents/alessio`, `engineer` → `stefano`, `product` → `walter`, `marketing` → `veronica`, `uiux` → `alessandra`, `tester` → `marwen`
- `shared-context/TEAM.json` che descrive il team attuale
- I `SOUL.md` esistenti copiati in `catalog/souls/` come sorgente del catalogo
- I 9 slash command aggiornati ai nuovi percorsi, più il passo di authoring dell'anima
- Riferimenti aggiornati in `CLAUDE.md`, `README.md`, `AGENTS.md`, `GEMINI.md`

`office-overlay` non richiede modifiche: non viene distribuito da `setup.sh`, e usa già gli id persona (`alessio`, `stefano`, …) che la migrazione non cambia. Fargli leggere `TEAM.json` per disporre N scrivanie resta un miglioramento successivo, fuori dalla portata di questo lavoro.

## Verifica

Il repo non ha infrastruttura di test. Si adotta **bats-core**, con le librerie di supporto `bats-assert` e `bats-support`, installate come git submodule in `tests/bats/` — così `git clone --recurse-submodules` basta a eseguire la suite, senza chiedere a chi contribuisce di installare nulla a mano.

```
tests/
├── bats/                    # submodule: bats-core, bats-assert, bats-support
├── helpers/
│   ├── setup.bash           # load delle librerie, TMPDIR isolata per test
│   └── fixtures.bash        # manifest di esempio: valido, corrotto, con duplicati
├── fixtures/
│   ├── team-valid.json
│   ├── team-duplicates.json
│   └── team-corrupt.json
├── team-lib.bats            # la libreria
├── scripts.bats             # gli otto script migrati
├── catalog.bats             # validità di catalog/roles.json
├── setup-wizard.bats        # generazione end-to-end via --config
└── hire.bats                # aggiunta di un profilo
```

Ogni test gira in una `TMPDIR` propria con il suo `TEAM.json`, esportata via `OFFICE_SHARED_DIR` — la stessa variabile che l'overlay Rust già rispetta. Nessun test tocca `shared-context/` del repo.

Esecuzione: `./tests/run.sh` (wrapper che verifica il submodule e lancia `bats tests/`), oppure `bats tests/team-lib.bats` per un singolo file.

Casi coperti:

- `team.sh` risolve ogni campo di una voce valida
- ID sconosciuto rifiutato, con gli id validi nel messaggio
- due persone con lo stesso ruolo convivono e restano distinte
- manifest mancante → exit 2 con messaggio, non traceback
- manifest corrotto → exit 2 con messaggio, non traceback
- generazione end-to-end via `--config` in una directory temporanea, confrontata con la struttura attesa
- ogni script migrato accetta un id valido del manifest e ne rifiuta uno inventato
- il wizard rifiuta una configurazione senza coordinatore
- `catalog/roles.json` è valido e ogni voce ha i campi obbligatori, `tension` incluso
- `hire.sh` aggiunge una persona, crea la cartella e aggiorna il manifest
- `hire.sh` rifiuta un id già presente e un ruolo fuori catalogo
- `hire.sh` non modifica nulla se uno dei passi fallisce

## Fasi

Quattro fasi committabili. Le prime due sono verificabili prima che la TUI esista.

0. **Infrastruttura di test** — bats-core e librerie come submodule, `tests/run.sh`, helper e fixture. Prima fase perché tutte le successive ci si appoggiano
1. **Catalogo** — `catalog/roles.json` con le 34 voci, `catalog/souls/` con le sei anime migrate, i cinque template di log, test di validità del catalogo
2. **Runtime** — `agents/lib/team.sh`, migrazione degli otto script, `TEAM.json` per questo repo, test della libreria e degli script
3. **Wizard** — riscrittura di `setup.sh` con gum, modalità `--config`, test di generazione end-to-end
4. **Aggiunta profilo** — `agents/hire.sh` sulle funzioni condivise della fase 3, con test di atomicità
5. **Migrazione repo** — `git mv` delle cartelle, slash command con authoring dell'anima, aggiornamento dei documenti

## Fuori portata

- Far leggere `TEAM.json` a `office-overlay` e disporre N scrivanie
- Rimuovere una persona da un team esistente: cancellare log, inbox e messaggi inviati è una decisione che merita un design suo
- Anime scritte a mano per le 28 figure nuove
