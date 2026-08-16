# TUI Team Setup — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sostituire il team fisso di sei ruoli con un team a composizione variabile, scelto da un wizard TUI su un catalogo di 34 figure e descritto da un manifest che tutti gli script leggono a runtime.

**Architecture:** `catalog/roles.json` descrive le figure possibili; `shared-context/TEAM.json` descrive il team reale. Due librerie bash separano le responsabilità: `agents/lib/team.sh` risolve il manifest ed è caricata da ogni script a ogni comando, `agents/lib/roster.sh` conosce il catalogo e le schermate `gum` e serve solo a `setup.sh` e `hire.sh`. Le `case` cablate sui sei nomi spariscono da tutti gli script.

**Tech Stack:** bash 3.2 (macOS di serie), `python3` per il JSON (già dipendenza di fatto), `gum` per la TUI, bats-core per i test.

**Spec:** `docs/superpowers/specs/2026-08-16-tui-team-setup-design.md`

## Global Constraints

- **bash 3.2 compatibile.** macOS ships bash 3.2. Niente array associativi (`declare -A`), niente `${var^^}`, niente `mapfile`. Usa `tr` per il case e loop `while read` per le liste.
- **Nessuna dipendenza nuova a runtime oltre gum.** Il JSON si parsa con `python3`, mai `jq`.
- **`gum` serve solo ai percorsi interattivi.** Ogni comando deve avere una forma ad argomenti che funziona senza gum, perché i test non pilotano una TUI.
- **Ogni errore utente esce con codice 2 e un messaggio in italiano su stderr.** Mai un traceback Python: sopprimi `2>/dev/null` su python3 e stampa tu il messaggio.
- **Scritture atomiche.** Ogni file in `shared-context/` letto da altri agenti si scrive su un temporaneo nella stessa directory e si promuove con `mv`.
- **ID agente:** nome della persona in lowercase, senza spazi né accenti. È la chiave in `AGENT-STATUS.json`, `inbox/<id>/`, `queues/<id>.json`.
- **`OFFICE_SHARED_DIR`** sovrascrive la posizione di `shared-context/`. Rispettala ovunque: è il meccanismo con cui i test isolano lo stato, ed è già rispettata dal watcher Rust dell'overlay.
- **Commit in italiano**, formato conventional commits (`feat:`, `test:`, `refactor:`, `docs:`).

---

## File Structure

**Nuovi:**

| File | Responsabilità |
|---|---|
| `catalog/roles.json` | Le 34 figure: dati strutturati per ruolo |
| `catalog/souls/<slug>.md` | Le sei anime scritte a mano |
| `catalog/templates/<name>.md` | Template dei log di ruolo e di HEARTBEAT |
| `agents/lib/team.sh` | Manifest a runtime: chi c'è nel team |
| `agents/lib/roster.sh` | Catalogo e generazione: chi potrebbe esserci |
| `agents/hire.sh` | Aggiunge una persona a un team esistente |
| `shared-context/TEAM.json` | Il team di questo repo |
| `tests/` | Suite bats |

**Modificati:** `setup.sh` (riscritto), `agents/setstatus.sh`, `agents/qtask.sh`, `agents/msg.sh`, `agents/ack.sh`, `agents/launch.sh`, `agents/iterm.sh`, `agents/dashboard.sh`, `agents/live-dashboard.sh`, i 9 file in `.claude/commands/`, `CLAUDE.md`, `README.md`, `AGENTS.md`, `GEMINI.md`.

**Spostati:** `agents/ceo/` → `agents/alessio/`, `engineer/` → `stefano/`, `product/` → `walter/`, `marketing/` → `veronica/`, `uiux/` → `alessandra/`, `tester/` → `marwen/`.

---

## Task 1: Infrastruttura di test

**Files:**
- Create: `tests/run.sh`, `tests/helpers/setup.bash`, `tests/helpers/fixtures.bash`, `tests/fixtures/team-valid.json`, `tests/fixtures/team-duplicates.json`, `tests/fixtures/team-corrupt.json`, `tests/smoke.bats`
- Modify: `.gitmodules` (creato dal comando submodule)

**Interfaces:**
- Produces: `setup_office_test` (helper bash che crea una `shared-context/` isolata e esporta `OFFICE_SHARED_DIR`), `OFFICE_ROOT` (variabile che punta alla radice del repo dentro i test).

- [ ] **Step 1: Aggiungi i submodule bats**

```bash
git submodule add https://github.com/bats-core/bats-core.git tests/bats/bats-core
git submodule add https://github.com/bats-core/bats-support.git tests/bats/bats-support
git submodule add https://github.com/bats-core/bats-assert.git tests/bats/bats-assert
```

- [ ] **Step 2: Scrivi l'helper di setup**

Crea `tests/helpers/setup.bash`:

```bash
#!/usr/bin/env bash
# Helper caricato da ogni file .bats.

OFFICE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export OFFICE_ROOT

load "$OFFICE_ROOT/tests/bats/bats-support/load.bash"
load "$OFFICE_ROOT/tests/bats/bats-assert/load.bash"

# Crea una shared-context/ isolata per il test corrente e la esporta.
# Ogni test che tocca lo stato DEVE chiamarla nel proprio setup().
setup_office_test() {
  OFFICE_TEST_DIR="$(mktemp -d)"
  mkdir -p "$OFFICE_TEST_DIR/shared-context"
  export OFFICE_SHARED_DIR="$OFFICE_TEST_DIR/shared-context"
}

teardown_office_test() {
  if [ -n "$OFFICE_TEST_DIR" ] && [ -d "$OFFICE_TEST_DIR" ]; then
    rm -rf "$OFFICE_TEST_DIR"
  fi
}

# Installa una fixture di manifest nella shared-context isolata.
use_manifest() {
  cp "$OFFICE_ROOT/tests/fixtures/$1" "$OFFICE_SHARED_DIR/TEAM.json"
}
```

- [ ] **Step 3: Scrivi le fixture**

Crea `tests/fixtures/team-valid.json`:

```json
{
  "version": 1,
  "team": [
    { "id": "alessio", "name": "Alessio", "role": "ceo", "label": "CEO / Founder",
      "folder": "agents/alessio", "log": null, "color": "#f5b400", "coordinator": true },
    { "id": "stefano", "name": "Stefano", "role": "engineer", "label": "Engineer (full-stack)",
      "folder": "agents/stefano", "log": "BUILD-LOG.md", "color": "#4a90e2", "coordinator": false },
    { "id": "marwen", "name": "Marwen", "role": "tester", "label": "Tester / QA",
      "folder": "agents/marwen", "log": "BUG-LOG.md", "color": "#2ecc71", "coordinator": false }
  ]
}
```

Crea `tests/fixtures/team-duplicates.json` — due persone sullo stesso ruolo:

```json
{
  "version": 1,
  "team": [
    { "id": "giulia", "name": "Giulia", "role": "pm", "label": "Project Manager",
      "folder": "agents/giulia", "log": "PLAN.md", "color": "#f5b400", "coordinator": true },
    { "id": "marco", "name": "Marco", "role": "backend", "label": "Backend Engineer",
      "folder": "agents/marco", "log": "BUILD-LOG.md", "color": "#4a90e2", "coordinator": false },
    { "id": "luca", "name": "Luca", "role": "backend", "label": "Backend Engineer",
      "folder": "agents/luca", "log": "BUILD-LOG.md", "color": "#5b6ee1", "coordinator": false }
  ]
}
```

Crea `tests/fixtures/team-corrupt.json` — JSON volutamente rotto:

```
{ "version": 1, "team": [ { "id": "alessio",
```

- [ ] **Step 4: Scrivi il test di fumo**

Crea `tests/smoke.bats`:

```bash
#!/usr/bin/env bats

load 'helpers/setup'

setup() { setup_office_test; }
teardown() { teardown_office_test; }

@test "l'infrastruttura di test funziona" {
  run echo "ok"
  assert_success
  assert_output "ok"
}

@test "setup_office_test crea una shared-context isolata" {
  [ -d "$OFFICE_SHARED_DIR" ]
  [ "$OFFICE_SHARED_DIR" != "$OFFICE_ROOT/shared-context" ]
}

@test "use_manifest installa la fixture" {
  use_manifest team-valid.json
  [ -f "$OFFICE_SHARED_DIR/TEAM.json" ]
}
```

- [ ] **Step 5: Scrivi il runner**

Crea `tests/run.sh` (`chmod +x`):

```bash
#!/usr/bin/env bash
# run.sh — esegue la suite bats.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATS="$SCRIPT_DIR/bats/bats-core/bin/bats"

if [ ! -x "$BATS" ]; then
  echo "Errore: bats-core non trovato in tests/bats/." >&2
  echo "Inizializza i submodule con: git submodule update --init --recursive" >&2
  exit 2
fi

exec "$BATS" "${@:-$SCRIPT_DIR}"
```

- [ ] **Step 6: Esegui la suite e verifica che passi**

Run: `./tests/run.sh`
Expected: 3 test, tutti PASS.

- [ ] **Step 7: Commit**

```bash
git add .gitmodules tests/
git commit -m "test: infrastruttura bats con fixture e helper isolati"
```

---

## Task 2: Catalogo dei ruoli

**Files:**
- Create: `catalog/roles.json`
- Test: `tests/catalog.bats`

**Interfaces:**
- Produces: `catalog/roles.json` con chiave radice `roles` (array). Ogni voce ha i campi `slug`, `label`, `category`, `coordinator`, `mission`, `can`, `cannot`, `collaborates`, `log`, `logTemplate`, `tension`. `log` e `logTemplate` possono essere `null`, gli altri campi sono obbligatori e non vuoti. `slug` è univoco.

- [ ] **Step 1: Scrivi il test di validità del catalogo**

Crea `tests/catalog.bats`:

```bash
#!/usr/bin/env bats

load 'helpers/setup'

CATALOG="$OFFICE_ROOT/catalog/roles.json"

@test "il catalogo è JSON valido" {
  run python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$OFFICE_ROOT/catalog/roles.json"
  assert_success
}

@test "il catalogo contiene almeno 34 ruoli" {
  run python3 -c "import json,sys; print(len(json.load(open(sys.argv[1]))['roles']))" "$OFFICE_ROOT/catalog/roles.json"
  assert_success
  [ "$output" -ge 34 ]
}

@test "ogni ruolo ha tutti i campi obbligatori non vuoti" {
  run python3 - "$OFFICE_ROOT/catalog/roles.json" <<'PY'
import json, sys
required = ["slug", "label", "category", "mission", "can", "cannot", "collaborates", "tension"]
roles = json.load(open(sys.argv[1]))["roles"]
errors = []
for r in roles:
    for f in required:
        if not r.get(f):
            errors.append(f"{r.get('slug','?')}: campo '{f}' mancante o vuoto")
    if "coordinator" not in r:
        errors.append(f"{r.get('slug','?')}: campo 'coordinator' mancante")
    if "log" not in r or "logTemplate" not in r:
        errors.append(f"{r.get('slug','?')}: campo 'log'/'logTemplate' mancante")
if errors:
    print("\n".join(errors))
    sys.exit(1)
PY
  assert_success
}

@test "gli slug sono univoci" {
  run python3 - "$OFFICE_ROOT/catalog/roles.json" <<'PY'
import json, sys
slugs = [r["slug"] for r in json.load(open(sys.argv[1]))["roles"]]
dupes = set(s for s in slugs if slugs.count(s) > 1)
if dupes:
    print("slug duplicati: " + ", ".join(sorted(dupes)))
    sys.exit(1)
PY
  assert_success
}

@test "esistono almeno cinque ruoli di coordinamento" {
  run python3 -c "import json,sys; print(sum(1 for r in json.load(open(sys.argv[1]))['roles'] if r['coordinator']))" "$OFFICE_ROOT/catalog/roles.json"
  assert_success
  [ "$output" -ge 5 ]
}

@test "collaborates contiene solo slug esistenti" {
  run python3 - "$OFFICE_ROOT/catalog/roles.json" <<'PY'
import json, sys
roles = json.load(open(sys.argv[1]))["roles"]
slugs = {r["slug"] for r in roles}
errors = []
for r in roles:
    for c in r["collaborates"]:
        if c not in slugs:
            errors.append(f"{r['slug']}: collabora con '{c}' che non esiste")
if errors:
    print("\n".join(errors))
    sys.exit(1)
PY
  assert_success
}

@test "i sei ruoli storici sono presenti" {
  for slug in ceo engineer product marketing uiux tester; do
    run python3 - "$OFFICE_ROOT/catalog/roles.json" "$slug" <<'PY'
import json, sys
slugs = {r["slug"] for r in json.load(open(sys.argv[1]))["roles"]}
sys.exit(0 if sys.argv[2] in slugs else 1)
PY
    assert_success
  done
}
```

- [ ] **Step 2: Esegui i test e verifica che falliscano**

Run: `./tests/run.sh tests/catalog.bats`
Expected: FAIL — `catalog/roles.json` non esiste.

- [ ] **Step 3: Scrivi il catalogo**

Crea `catalog/roles.json`. Struttura e prima voce complete:

```json
{
  "version": 1,
  "roles": [
    {
      "slug": "ceo",
      "label": "CEO / Founder",
      "category": "Coordinamento",
      "coordinator": true,
      "mission": "Direzione strategica e decisione finale. Alloca le persone, arbitra i conflitti, sceglie cosa non si fa.",
      "can": [
        "Accesso completo a ogni file del progetto",
        "Cambiare le priorità di roadmap documentando il perché",
        "Fare override di qualsiasi altro agente"
      ],
      "cannot": [
        "Scavalcare un blocco critico del Tester senza dichiararlo per iscritto"
      ],
      "collaborates": ["product", "engineer", "marketing", "uiux", "tester"],
      "log": null,
      "logTemplate": null,
      "tension": "Taglia lo scope quando il team promette più di quanto la settimana contenga"
    }
  ]
}
```

Le 34 voci sono enumerate nella spec, sezione "Il catalogo: 34 figure", che fissa `slug`, `label`, `category`, `log` e quali hanno `coordinator: true`. Per ogni voce scrivi `mission` (una o due frasi su cosa possiede), `can` (2-4 voci), `cannot` (1-3 voci), `collaborates` (slug esistenti nel catalogo) e `tension` (una frase su contro chi spinge e su cosa).

I `logTemplate` ammessi sono cinque: `build-log`, `backlog`, `calendar`, `review-log`, `bug-log`. Un ruolo il cui log non rientra in nessuno usa `generic`. Un ruolo senza log ha `log: null` e `logTemplate: null`.

Regole di contenuto:
- `cannot` deve contenere almeno un confine reale verso un altro ruolo del catalogo, non generici come "non fare danni". Il senso del campo è che due agenti non si calpestino.
- `tension` nomina un attrito concreto. "Collabora con tutti" non è un attrito.
- `collaborates` elenca solo slug presenti nel catalogo, altrimenti il test fallisce.

- [ ] **Step 4: Esegui i test e verifica che passino**

Run: `./tests/run.sh tests/catalog.bats`
Expected: 6 test PASS.

- [ ] **Step 5: Commit**

```bash
git add catalog/roles.json tests/catalog.bats
git commit -m "feat: catalogo di 34 ruoli con dati strutturati e attriti dichiarati"
```

---

## Task 3: Anime e template

**Files:**
- Create: `catalog/souls/ceo.md`, `catalog/souls/engineer.md`, `catalog/souls/product.md`, `catalog/souls/marketing.md`, `catalog/souls/uiux.md`, `catalog/souls/tester.md`
- Create: `catalog/templates/heartbeat.md`, `catalog/templates/build-log.md`, `catalog/templates/backlog.md`, `catalog/templates/calendar.md`, `catalog/templates/review-log.md`, `catalog/templates/bug-log.md`, `catalog/templates/generic.md`
- Create: `catalog/SOUL-AUTHORING.md`
- Test: `tests/catalog.bats` (esteso)

**Interfaces:**
- Consumes: `catalog/roles.json` da Task 2 (per sapere quali `logTemplate` devono esistere).
- Produces: file template che contengono il segnaposto `__AGENT_NAME__` dove va il nome della persona e `__ROLE_LABEL__` dove va l'etichetta del ruolo. La sostituzione la fa `roster.sh` in Task 8.

- [ ] **Step 1: Estendi i test del catalogo**

Aggiungi a `tests/catalog.bats`:

```bash
@test "ogni logTemplate referenziato esiste come file" {
  run python3 - "$OFFICE_ROOT/catalog/roles.json" "$OFFICE_ROOT/catalog/templates" <<'PY'
import json, os, sys
roles = json.load(open(sys.argv[1]))["roles"]
missing = []
for r in roles:
    t = r.get("logTemplate")
    if t and not os.path.isfile(os.path.join(sys.argv[2], t + ".md")):
        missing.append(f"{r['slug']}: template '{t}.md' mancante")
if missing:
    print("\n".join(missing))
    sys.exit(1)
PY
  assert_success
}

@test "le sei anime storiche esistono" {
  for slug in ceo engineer product marketing uiux tester; do
    [ -f "$OFFICE_ROOT/catalog/souls/$slug.md" ]
  done
}

@test "il template heartbeat esiste e contiene il segnaposto del nome" {
  [ -f "$OFFICE_ROOT/catalog/templates/heartbeat.md" ]
  run grep -q "__AGENT_NAME__" "$OFFICE_ROOT/catalog/templates/heartbeat.md"
  assert_success
}

@test "le istruzioni di authoring esistono" {
  [ -f "$OFFICE_ROOT/catalog/SOUL-AUTHORING.md" ]
}
```

- [ ] **Step 2: Esegui i test e verifica che falliscano**

Run: `./tests/run.sh tests/catalog.bats`
Expected: FAIL sui quattro test nuovi.

- [ ] **Step 3: Migra le sei anime**

Copia il contenuto dei `SOUL.md` esistenti nel catalogo, sostituendo i nomi propri con `__AGENT_NAME__`:

```bash
mkdir -p catalog/souls
cp agents/ceo/SOUL.md       catalog/souls/ceo.md
cp agents/engineer/SOUL.md  catalog/souls/engineer.md
cp agents/product/SOUL.md   catalog/souls/product.md
cp agents/marketing/SOUL.md catalog/souls/marketing.md
cp agents/uiux/SOUL.md      catalog/souls/uiux.md
cp agents/tester/SOUL.md    catalog/souls/tester.md
```

Poi in ogni file sostituisci a mano il nome proprio con `__AGENT_NAME__`: `Alessio` in `ceo.md`, `Stefano` in `engineer.md`, `Walter` in `product.md`, `Veronica` in `marketing.md`, `Alessandra` in `uiux.md`, `Marwen` in `tester.md`. Attenzione ai riferimenti incrociati: `engineer.md` cita gli altri agenti per nome e quei nomi vanno lasciati come sono — nel catalogo diventano nomi di esempio, e `roster.sh` non li tocca. Sostituisci solo il nome del proprietario del file.

Gli originali in `agents/*/SOUL.md` restano dove sono: li sposta Task 12.

- [ ] **Step 4: Scrivi i template**

Crea `catalog/templates/heartbeat.md`:

```markdown
# __AGENT_NAME__ — __ROLE_LABEL__ — Heartbeat

## Ultimo aggiornamento
[DATA]

## Su cosa sto lavorando
- [Priorità di questa sessione]

## Fatto in questa sessione
- [Cosa è stato completato]

## Bloccato su
- [Niente / cosa è fermo e da chi dipende]

## Prossima sessione
- [Da dove riprendere]
```

Crea `catalog/templates/build-log.md`:

```markdown
# __AGENT_NAME__ — Build Log

Registro di cosa è stato costruito, deployato e con quale piano di rollback.

## [DATA]
- **Fatto:**
- **Deployato in:**
- **Rollback:**
- **Note:**
```

Crea `catalog/templates/backlog.md`:

```markdown
# __AGENT_NAME__ — Backlog

## Now (sprint corrente)
- [Massimo 3 voci]

## Next (2 settimane)
- [Prossima spec]

## Later (trimestre)
- [Idea futura]

## Fatto
- [Voce completata, con data]
```

Crea `catalog/templates/calendar.md`:

```markdown
# __AGENT_NAME__ — Calendario contenuti

## In bozza
- [Titolo, canale, data prevista]

## Pubblicato
- [Titolo, canale, data, risultato]
```

Crea `catalog/templates/review-log.md`:

```markdown
# __AGENT_NAME__ — Review Log

Ogni review chiude con APPROVED o REJECTED. Un rifiuto porta sempre prove e una soluzione.

## [DATA] — [Pagina o componente]
- **Esito:** APPROVED / REJECTED
- **Problemi:**
- **Soluzione proposta:**
```

Crea `catalog/templates/bug-log.md`:

```markdown
# __AGENT_NAME__ — Bug Log

Un bug senza passi di riproduzione non è un bug report.

## BUG-000 — [Titolo]
- **Severità:** critica / alta / media / bassa
- **Riproduzione:**
- **Atteso:**
- **Ottenuto:**
- **Stato:** aperto / in fix / chiuso
```

Crea `catalog/templates/generic.md`:

```markdown
# __AGENT_NAME__ — __ROLE_LABEL__ — Log

## [DATA]
- **Fatto:**
- **Deciso:**
- **Aperto:**
```

- [ ] **Step 5: Scrivi le istruzioni di authoring**

Crea `catalog/SOUL-AUTHORING.md`:

```markdown
# Come si scrive un SOUL.md

Un SOUL.md descrive **come pensa** un agente. Non cosa può toccare — quello sta in IDENTITY.md ed è generato dai dati.

## Quando ti serve

Quando carichi un ruolo e `SOUL.md` non esiste nella sua cartella. Leggi `ROLE-BRIEF.md` della persona, `shared-context/THESIS.md` e `shared-context/BRAND-GUIDE.md`, poi scrivi l'anima calata su **questo** progetto: un tester in un progetto di pagamenti e un tester in un blog non hanno le stesse ossessioni.

## Struttura

- **Chi sei** — due o tre frasi. Il mestiere e l'atteggiamento, non il curriculum.
- **Come pensi** — 4-6 principi operativi. Ognuno dice cosa fai in una situazione concreta, non un valore astratto. "Un bug senza passi di riproduzione non è un bug report" vale; "credo nella qualità" no.
- **Cosa rifiuti** — 3-5 righe. Le cose che non fai anche se te le chiedono, e cosa proponi al loro posto. **Questa sezione è obbligatoria.** Un agente senza rifiuti è un sì-uomo, e un sì-uomo non serve a un team.
- **Come comunichi** — come suoni quando dai una brutta notizia, e come formuli il disaccordo.
- **Con chi litighi** — il campo `tension` del brief, espanso: contro chi spingi, su cosa, e perché è utile al progetto.

## Regole

- 40-80 righe. Più corto è vago, più lungo non viene letto.
- Seconda persona singolare, presente. "Chiedi sempre i passi di riproduzione", non "il tester dovrebbe chiedere".
- Concreto sul dominio del progetto: cita i suoi file, i suoi rischi, il suo stack.
- Niente sovrapposizioni con IDENTITY.md: se stai elencando permessi, hai sbagliato file.
- Il tono segue `shared-context/BRAND-GUIDE.md`.

## Riferimento

`catalog/souls/tester.md` e `catalog/souls/uiux.md` sono i due esempi da imitare per stile e livello di concretezza.
```

- [ ] **Step 6: Esegui i test e verifica che passino**

Run: `./tests/run.sh tests/catalog.bats`
Expected: 10 test PASS.

- [ ] **Step 7: Commit**

```bash
git add catalog/ tests/catalog.bats
git commit -m "feat: anime storiche nel catalogo, template di log e regole di authoring"
```

---

## Task 4: Libreria del manifest

**Files:**
- Create: `agents/lib/team.sh`
- Test: `tests/team-lib.bats`

**Interfaces:**
- Consumes: le fixture di Task 1, `OFFICE_SHARED_DIR`.
- Produces:
  - `team_manifest_path` → stampa il percorso del manifest
  - `team_require_manifest` → exit 2 con messaggio se manca o è corrotto
  - `team_ids` → un id per riga, nell'ordine del manifest
  - `team_validate <id>` → return 0/1, messaggio su stderr in caso di errore
  - `team_get <id> <campo>` → stampa il valore; campi `name|role|label|folder|log|color|coordinator`; `null` stampa stringa vuota; return 1 se l'id non esiste
  - `team_coordinators` → un id per riga

- [ ] **Step 1: Scrivi i test della libreria**

Crea `tests/team-lib.bats`:

```bash
#!/usr/bin/env bats

load 'helpers/setup'

setup() {
  setup_office_test
  source "$OFFICE_ROOT/agents/lib/team.sh"
}
teardown() { teardown_office_test; }

@test "team_ids elenca gli id nell'ordine del manifest" {
  use_manifest team-valid.json
  run team_ids
  assert_success
  assert_line --index 0 "alessio"
  assert_line --index 1 "stefano"
  assert_line --index 2 "marwen"
}

@test "team_get restituisce il nome" {
  use_manifest team-valid.json
  run team_get stefano name
  assert_success
  assert_output "Stefano"
}

@test "team_get restituisce la cartella" {
  use_manifest team-valid.json
  run team_get stefano folder
  assert_success
  assert_output "agents/stefano"
}

@test "team_get su un log null restituisce stringa vuota" {
  use_manifest team-valid.json
  run team_get alessio log
  assert_success
  assert_output ""
}

@test "team_get su coordinator restituisce true o false" {
  use_manifest team-valid.json
  run team_get alessio coordinator
  assert_output "true"
  run team_get stefano coordinator
  assert_output "false"
}

@test "team_get su un id inesistente fallisce" {
  use_manifest team-valid.json
  run team_get nessuno name
  assert_failure
}

@test "team_validate accetta un id del team" {
  use_manifest team-valid.json
  run team_validate marwen
  assert_success
}

@test "team_validate rifiuta un id sconosciuto elencando quelli validi" {
  use_manifest team-valid.json
  run team_validate pippo
  assert_failure
  assert_output --partial "pippo"
  assert_output --partial "alessio"
  assert_output --partial "stefano"
}

@test "due persone sullo stesso ruolo restano distinte" {
  use_manifest team-duplicates.json
  run team_get marco name
  assert_output "Marco"
  run team_get luca name
  assert_output "Luca"
  run team_get marco role
  assert_output "backend"
  run team_get luca role
  assert_output "backend"
}

@test "team_coordinators elenca solo chi coordina" {
  use_manifest team-duplicates.json
  run team_coordinators
  assert_success
  assert_output "giulia"
}

@test "manifest mancante esce con codice 2 e messaggio leggibile" {
  run team_require_manifest
  [ "$status" -eq 2 ]
  assert_output --partial "TEAM.json"
  assert_output --partial "setup.sh"
  refute_output --partial "Traceback"
}

@test "manifest corrotto esce con codice 2 e messaggio leggibile" {
  use_manifest team-corrupt.json
  run team_require_manifest
  [ "$status" -eq 2 ]
  assert_output --partial "JSON"
  refute_output --partial "Traceback"
}

@test "OFFICE_SHARED_DIR determina quale manifest viene letto" {
  use_manifest team-valid.json
  run team_manifest_path
  assert_output "$OFFICE_SHARED_DIR/TEAM.json"
}
```

- [ ] **Step 2: Esegui i test e verifica che falliscano**

Run: `./tests/run.sh tests/team-lib.bats`
Expected: FAIL — `agents/lib/team.sh` non esiste.

- [ ] **Step 3: Scrivi la libreria**

Crea `agents/lib/team.sh`:

```bash
#!/usr/bin/env bash
# team.sh — accesso al manifest del team (shared-context/TEAM.json).
# Sourceata da ogni script che deve sapere chi c'è nel team.
#
# Uso:
#   source "$(dirname "$0")/lib/team.sh"
#   team_validate stefano || exit 1
#   NOME=$(team_get stefano name)

TEAM_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

team_manifest_path() {
  if [ -n "$OFFICE_TEAM_FILE" ]; then
    echo "$OFFICE_TEAM_FILE"
  elif [ -n "$OFFICE_SHARED_DIR" ]; then
    echo "$OFFICE_SHARED_DIR/TEAM.json"
  else
    echo "$TEAM_LIB_DIR/../../shared-context/TEAM.json"
  fi
}

team_require_manifest() {
  local manifest
  manifest="$(team_manifest_path)"

  if [ ! -f "$manifest" ]; then
    echo "Errore: $manifest non trovato." >&2
    echo "Questo progetto non ha un team configurato. Lancia ./setup.sh per crearlo." >&2
    exit 2
  fi

  if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$manifest" >/dev/null 2>&1; then
    echo "Errore: $manifest non è un JSON valido." >&2
    echo "Correggi il file a mano oppure rigeneralo con ./setup.sh." >&2
    exit 2
  fi
}

team_ids() {
  team_require_manifest
  python3 - "$(team_manifest_path)" <<'PY' 2>/dev/null
import json, sys
for m in json.load(open(sys.argv[1])).get("team", []):
    print(m["id"])
PY
}

team_get() {
  local id="$1" field="$2"
  team_require_manifest
  python3 - "$(team_manifest_path)" "$id" "$field" <<'PY' 2>/dev/null
import json, sys
path, wanted, field = sys.argv[1], sys.argv[2], sys.argv[3]
for m in json.load(open(path)).get("team", []):
    if m.get("id") == wanted:
        v = m.get(field)
        if v is None:
            print("")
        elif isinstance(v, bool):
            print("true" if v else "false")
        else:
            print(v)
        sys.exit(0)
sys.exit(1)
PY
}

team_validate() {
  local id="$1"
  team_require_manifest

  if team_ids | grep -qx -- "$id"; then
    return 0
  fi

  echo "Errore: agente '$id' non riconosciuto." >&2
  echo "Agenti del team: $(team_ids | tr '\n' ' ')" >&2
  return 1
}

team_coordinators() {
  team_require_manifest
  python3 - "$(team_manifest_path)" <<'PY' 2>/dev/null
import json, sys
for m in json.load(open(sys.argv[1])).get("team", []):
    if m.get("coordinator"):
        print(m["id"])
PY
}
```

- [ ] **Step 4: Esegui i test e verifica che passino**

Run: `./tests/run.sh tests/team-lib.bats`
Expected: 13 test PASS.

- [ ] **Step 5: Commit**

```bash
git add agents/lib/team.sh tests/team-lib.bats
git commit -m "feat: libreria team.sh per la risoluzione del manifest a runtime"
```

---

## Task 5: Manifest di questo repo e migrazione di setstatus/qtask

**Files:**
- Create: `shared-context/TEAM.json`
- Modify: `agents/setstatus.sh`, `agents/qtask.sh`
- Test: `tests/scripts.bats`

**Interfaces:**
- Consumes: `team_validate`, `team_ids`, `team_get` da Task 4.
- Produces: `shared-context/TEAM.json` con i sei agenti attuali. Le cartelle restano quelle vecchie (`agents/ceo` …) fino a Task 12: il campo `folder` in questo commit riflette la realtà corrente e verrà aggiornato lì.

- [ ] **Step 1: Scrivi i test degli script**

Crea `tests/scripts.bats`:

```bash
#!/usr/bin/env bats

load 'helpers/setup'

setup() {
  setup_office_test
  use_manifest team-valid.json
}
teardown() { teardown_office_test; }

@test "setstatus accetta un agente del manifest" {
  run "$OFFICE_ROOT/agents/setstatus.sh" stefano WORKING "Fix BUG-001"
  assert_success
  run python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['stefano']['status'])" "$OFFICE_SHARED_DIR/AGENT-STATUS.json"
  assert_output "WORKING"
}

@test "setstatus registra il task" {
  "$OFFICE_ROOT/agents/setstatus.sh" stefano WORKING "Fix BUG-001"
  run python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['stefano']['task'])" "$OFFICE_SHARED_DIR/AGENT-STATUS.json"
  assert_output "Fix BUG-001"
}

@test "setstatus rifiuta un agente fuori dal manifest" {
  run "$OFFICE_ROOT/agents/setstatus.sh" pippo WORKING "qualcosa"
  assert_failure
  assert_output --partial "pippo"
}

@test "setstatus rifiuta uno status non valido" {
  run "$OFFICE_ROOT/agents/setstatus.sh" stefano DORMENDO
  assert_failure
  assert_output --partial "DORMENDO"
}

@test "setstatus richiede un task quando lo status è WORKING" {
  run "$OFFICE_ROOT/agents/setstatus.sh" stefano WORKING
  assert_failure
  assert_output --partial "task"
}

@test "setstatus inizializza il file con gli agenti del manifest" {
  "$OFFICE_ROOT/agents/setstatus.sh" stefano IDLE
  run python3 -c "import json,sys; print(' '.join(sorted(json.load(open(sys.argv[1])).keys())))" "$OFFICE_SHARED_DIR/AGENT-STATUS.json"
  assert_output "alessio marwen stefano"
}

@test "setstatus con team a ruoli duplicati tiene le persone distinte" {
  use_manifest team-duplicates.json
  "$OFFICE_ROOT/agents/setstatus.sh" marco WORKING "API ordini"
  "$OFFICE_ROOT/agents/setstatus.sh" luca WORKING "API pagamenti"
  run python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d['marco']['task'], '|', d['luca']['task'])" "$OFFICE_SHARED_DIR/AGENT-STATUS.json"
  assert_output "API ordini | API pagamenti"
}

@test "qtask accoda e lista per un agente del manifest" {
  run "$OFFICE_ROOT/agents/qtask.sh" add marwen "Ritesta il checkout"
  assert_success
  run "$OFFICE_ROOT/agents/qtask.sh" list marwen
  assert_output --partial "Ritesta il checkout"
}

@test "qtask rifiuta un agente fuori dal manifest" {
  run "$OFFICE_ROOT/agents/qtask.sh" add pippo "qualcosa"
  assert_failure
  assert_output --partial "pippo"
}

@test "qtask done rimuove il task" {
  "$OFFICE_ROOT/agents/qtask.sh" add marwen "Ritesta il checkout"
  TASK_ID=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))[0]['id'])" "$OFFICE_SHARED_DIR/queues/marwen.json")
  run "$OFFICE_ROOT/agents/qtask.sh" done marwen "$TASK_ID"
  assert_success
  run "$OFFICE_ROOT/agents/qtask.sh" list marwen
  assert_output --partial "vuota"
}

@test "senza manifest gli script escono con codice 2" {
  rm "$OFFICE_SHARED_DIR/TEAM.json"
  run "$OFFICE_ROOT/agents/setstatus.sh" stefano IDLE
  [ "$status" -eq 2 ]
  refute_output --partial "Traceback"
}
```

- [ ] **Step 2: Esegui i test e verifica che falliscano**

Run: `./tests/run.sh tests/scripts.bats`
Expected: FAIL — gli script usano ancora la `case` cablata e ignorano `OFFICE_SHARED_DIR`.

- [ ] **Step 3: Scrivi il manifest di questo repo**

Crea `shared-context/TEAM.json`:

```json
{
  "version": 1,
  "team": [
    { "id": "alessio", "name": "Alessio", "role": "ceo", "label": "CEO / Founder",
      "folder": "agents/ceo", "log": null, "color": "#f5b400", "coordinator": true },
    { "id": "stefano", "name": "Stefano", "role": "engineer", "label": "Engineer (full-stack)",
      "folder": "agents/engineer", "log": "BUILD-LOG.md", "color": "#4a90e2", "coordinator": false },
    { "id": "walter", "name": "Walter", "role": "product", "label": "Product Manager",
      "folder": "agents/product", "log": "BACKLOG.md", "color": "#9b59b6", "coordinator": false },
    { "id": "veronica", "name": "Veronica", "role": "marketing", "label": "Marketing & Documentation",
      "folder": "agents/marketing", "log": "CONTENT-CALENDAR.md", "color": "#e74c3c", "coordinator": false },
    { "id": "alessandra", "name": "Alessandra", "role": "uiux", "label": "UI/UX Specialist",
      "folder": "agents/uiux", "log": "UI-REVIEW-LOG.md", "color": "#1abc9c", "coordinator": false },
    { "id": "marwen", "name": "Marwen", "role": "tester", "label": "Tester / QA",
      "folder": "agents/tester", "log": "BUG-LOG.md", "color": "#2ecc71", "coordinator": false }
  ]
}
```

I `color` sono gli stessi di `office-overlay/src/agents.ts`, in esadecimale.

- [ ] **Step 4: Migra setstatus.sh**

Sostituisci in `agents/setstatus.sh` la risoluzione del percorso e la `case` di validazione. Il file diventa:

```bash
#!/bin/bash
# setstatus.sh — Aggiorna lo status di un agente nel dashboard centrale
# Uso:     ./agents/setstatus.sh <agente> <WORKING|IDLE|STANDBY> ["task corrente"]
# Esempio: ./agents/setstatus.sh stefano WORKING "Fix BUG-047 su /checkout"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/team.sh"

SHARED_DIR="${OFFICE_SHARED_DIR:-$SCRIPT_DIR/../shared-context}"
STATUS_FILE="$SHARED_DIR/AGENT-STATUS.json"

AGENT=$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')
STATUS=$(echo "${2:-}" | tr '[:lower:]' '[:upper:]')
TASK="${3:-}"

if [[ -z "$AGENT" || -z "$STATUS" ]]; then
  echo "Uso: ./agents/setstatus.sh <agente> <WORKING|IDLE|STANDBY> [\"task corrente\"]" >&2
  echo "Agenti: $(team_ids | tr '\n' ' ')" >&2
  exit 1
fi

team_validate "$AGENT" || exit 1

case "$STATUS" in
  WORKING|IDLE|STANDBY) ;;
  *) echo "Errore: status '$STATUS' non valido. Usa: WORKING, IDLE, STANDBY" >&2; exit 1 ;;
esac

if [[ "$STATUS" == "WORKING" && -z "$TASK" ]]; then
  echo "Errore: WORKING richiede una descrizione del task." >&2
  echo "Esempio: ./agents/setstatus.sh $AGENT WORKING \"Fix BUG-047 su /checkout\"" >&2
  exit 1
fi

mkdir -p "$SHARED_DIR"

# Inizializza il file con gli agenti presenti nel manifest.
if [[ ! -f "$STATUS_FILE" ]]; then
  team_ids | python3 - "$STATUS_FILE" <<'PY'
import json, sys
ids = [line.strip() for line in sys.stdin if line.strip()]
data = {a: {"status": "STANDBY", "task": "", "ts": ""} for a in ids}
tmp = sys.argv[1] + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
import os
os.replace(tmp, sys.argv[1])
PY
fi

TIMESTAMP=$(date "+%Y-%m-%dT%H:%M:%S")

python3 - "$STATUS_FILE" "$AGENT" "$STATUS" "$TIMESTAMP" "$TASK" <<'PY'
import json, os, sys
path, agent, status, ts, task = sys.argv[1:6]
with open(path) as f:
    data = json.load(f)
data[agent] = {"status": status, "task": task, "ts": ts}
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
os.replace(tmp, path)
PY

echo "  ✓ $AGENT → $STATUS${TASK:+ (\"$TASK\")}"
```

Nota le due differenze oltre alla validazione: `OFFICE_SHARED_DIR` è rispettata, e le scritture passano da `os.replace` su un temporaneo nella stessa directory — atomiche, come richiesto dai vincoli globali.

- [ ] **Step 5: Migra qtask.sh**

In `agents/qtask.sh` applica le stesse tre modifiche:

1. Dopo `SCRIPT_DIR=...` aggiungi `source "$SCRIPT_DIR/lib/team.sh"`.
2. Sostituisci `QUEUES_DIR="$SCRIPT_DIR/../shared-context/queues"` con:

```bash
SHARED_DIR="${OFFICE_SHARED_DIR:-$SCRIPT_DIR/../shared-context}"
QUEUES_DIR="$SHARED_DIR/queues"
```

3. Sostituisci il blocco `case "$AGENT" in alessio|stefano|...` con `team_validate "$AGENT" || exit 1`, e nella funzione `usage()` sostituisci la riga `echo "Agenti: alessio, ..."` con `echo "Agenti: $(team_ids | tr '\n' ' ')"`.

4. Nei tre blocchi `python3` che scrivono `$QUEUE_FILE`, sostituisci la scrittura diretta con scrittura su temporaneo e `os.replace`, come in `setstatus.sh`.

- [ ] **Step 6: Esegui i test e verifica che passino**

Run: `./tests/run.sh tests/scripts.bats`
Expected: 11 test PASS.

- [ ] **Step 7: Verifica che il repo reale funzioni ancora**

```bash
./agents/setstatus.sh stefano WORKING "verifica migrazione"
./agents/setstatus.sh stefano IDLE
./agents/qtask.sh list marwen
```

Expected: nessun errore, e `shared-context/AGENT-STATUS.json` aggiornato con i sei agenti intatti.

- [ ] **Step 8: Commit**

```bash
git add shared-context/TEAM.json agents/setstatus.sh agents/qtask.sh tests/scripts.bats
git commit -m "refactor: setstatus e qtask leggono il team dal manifest"
```

---

## Task 6: Migrazione di msg.sh e ack.sh

**Files:**
- Modify: `agents/msg.sh`, `agents/ack.sh`
- Test: `tests/messaging.bats`

**Interfaces:**
- Consumes: `team_validate`, `team_get` da Task 4.
- Produces: nessuna interfaccia nuova. `MSG-LOG.jsonl` e `inbox/<id>/` mantengono il formato attuale.

- [ ] **Step 1: Scrivi i test della messaggistica**

Crea `tests/messaging.bats`:

```bash
#!/usr/bin/env bats

load 'helpers/setup'

setup() {
  setup_office_test
  use_manifest team-valid.json
  export OFFICE_NO_ITERM=1
}
teardown() { teardown_office_test; }

@test "msg accetta mittente e destinatario del manifest" {
  run "$OFFICE_ROOT/agents/msg.sh" stefano marwen "Fix pronto"
  assert_success
}

@test "msg scrive un evento SENT nel log" {
  "$OFFICE_ROOT/agents/msg.sh" stefano marwen "Fix pronto"
  run grep -c '"type": *"SENT"' "$OFFICE_SHARED_DIR/MSG-LOG.jsonl"
  assert_output "1"
}

@test "msg deposita il messaggio nell'inbox del destinatario" {
  "$OFFICE_ROOT/agents/msg.sh" stefano marwen "Fix pronto"
  run bash -c "ls '$OFFICE_SHARED_DIR/inbox/marwen/' | wc -l | tr -d ' '"
  assert_output "1"
}

@test "msg usa il nome visualizzato dal manifest" {
  "$OFFICE_ROOT/agents/msg.sh" stefano marwen "Fix pronto"
  run grep -q '"from": *"Stefano"' "$OFFICE_SHARED_DIR/MSG-LOG.jsonl"
  assert_success
}

@test "msg rifiuta un mittente fuori dal manifest" {
  run "$OFFICE_ROOT/agents/msg.sh" pippo marwen "ciao"
  assert_failure
  assert_output --partial "pippo"
}

@test "msg rifiuta un destinatario fuori dal manifest" {
  run "$OFFICE_ROOT/agents/msg.sh" stefano pippo "ciao"
  assert_failure
  assert_output --partial "pippo"
}

@test "msg rifiuta mittente e destinatario coincidenti" {
  run "$OFFICE_ROOT/agents/msg.sh" stefano stefano "ciao"
  assert_failure
}

@test "msg funziona con un team a ruoli duplicati" {
  use_manifest team-duplicates.json
  run "$OFFICE_ROOT/agents/msg.sh" marco luca "Ti passo lo schema"
  assert_success
  run grep -q '"to": *"Luca"' "$OFFICE_SHARED_DIR/MSG-LOG.jsonl"
  assert_success
}

@test "ack registra un evento ACK per un messaggio esistente" {
  "$OFFICE_ROOT/agents/msg.sh" stefano marwen "Fix pronto"
  MSG_ID=$(python3 -c "
import json,sys
for line in open(sys.argv[1]):
    e=json.loads(line)
    if e.get('type')=='SENT':
        print(e['id']); break
" "$OFFICE_SHARED_DIR/MSG-LOG.jsonl")
  run "$OFFICE_ROOT/agents/ack.sh" "$MSG_ID" marwen
  assert_success
  run grep -c '"type": *"ACK"' "$OFFICE_SHARED_DIR/MSG-LOG.jsonl"
  assert_output "1"
}

@test "ack rifiuta un agente fuori dal manifest" {
  run "$OFFICE_ROOT/agents/ack.sh" msg-inesistente pippo
  assert_failure
  assert_output --partial "pippo"
}

@test "il log resta append-only: SENT sopravvive all'ACK" {
  "$OFFICE_ROOT/agents/msg.sh" stefano marwen "Fix pronto"
  MSG_ID=$(python3 -c "
import json,sys
for line in open(sys.argv[1]):
    e=json.loads(line)
    if e.get('type')=='SENT':
        print(e['id']); break
" "$OFFICE_SHARED_DIR/MSG-LOG.jsonl")
  "$OFFICE_ROOT/agents/ack.sh" "$MSG_ID" marwen
  run grep -c '"type": *"SENT"' "$OFFICE_SHARED_DIR/MSG-LOG.jsonl"
  assert_output "1"
}
```

- [ ] **Step 2: Esegui i test e verifica che falliscano**

Run: `./tests/run.sh tests/messaging.bats`
Expected: FAIL.

- [ ] **Step 3: Migra msg.sh**

In `agents/msg.sh`:

1. Dopo `SCRIPT_DIR=...` aggiungi `source "$SCRIPT_DIR/lib/team.sh"`.
2. Sostituisci i percorsi:

```bash
SHARED_DIR="${OFFICE_SHARED_DIR:-$SCRIPT_DIR/../shared-context}"
LOG_FILE="$SHARED_DIR/MSG-LOG.jsonl"
INBOX_DIR="$SHARED_DIR/inbox"
```

3. Elimina la funzione `resolve_name()` e i due blocchi che la usano. Al loro posto:

```bash
team_validate "$FROM" || exit 1
team_validate "$RECIPIENT" || exit 1

FROM_NAME=$(team_get "$FROM" name)
WINDOW_NAME=$(team_get "$RECIPIENT" name)
```

4. Il messaggio d'uso iniziale usa `echo "Agenti: $(team_ids | tr '\n' ' ')" >&2`.

5. Racchiudi la consegna AppleScript a iTerm2 in una guardia, perché i test non devono aprire finestre:

```bash
if [ -z "$OFFICE_NO_ITERM" ] && command -v osascript >/dev/null 2>&1; then
  # blocco osascript esistente, invariato
  :
fi
```

- [ ] **Step 4: Migra ack.sh**

Applica le stesse cinque modifiche a `agents/ack.sh`: `source` della libreria, percorsi da `SHARED_DIR`, `team_validate` al posto della `case`, `team_get <id> name` al posto di `resolve_name`, guardia `OFFICE_NO_ITERM` sulla notifica.

- [ ] **Step 5: Esegui i test e verifica che passino**

Run: `./tests/run.sh tests/messaging.bats`
Expected: 11 test PASS.

- [ ] **Step 6: Commit**

```bash
git add agents/msg.sh agents/ack.sh tests/messaging.bats
git commit -m "refactor: msg e ack risolvono i nomi dal manifest"
```

---

## Task 7: Migrazione di launch, iterm e dashboard

**Files:**
- Modify: `agents/launch.sh`, `agents/iterm.sh`, `agents/dashboard.sh`, `agents/live-dashboard.sh`
- Test: `tests/scripts.bats` (esteso)

**Interfaces:**
- Consumes: `team_ids`, `team_get` da Task 4.
- Produces: `launch.sh` e `iterm.sh` accettano un `--dry-run` che stampa il comando invece di eseguirlo, così i test verificano la costruzione del prompt senza avviare Claude né aprire iTerm2.

- [ ] **Step 1: Estendi i test**

Aggiungi a `tests/scripts.bats`:

```bash
@test "launch costruisce il prompt dalla cartella del manifest" {
  run "$OFFICE_ROOT/agents/launch.sh" --dry-run stefano
  assert_success
  assert_output --partial "Stefano"
  assert_output --partial "agents/stefano/SOUL.md"
  assert_output --partial "agents/stefano/IDENTITY.md"
}

@test "launch rifiuta un agente fuori dal manifest" {
  run "$OFFICE_ROOT/agents/launch.sh" --dry-run pippo
  assert_failure
  assert_output --partial "pippo"
}

@test "launch senza argomenti elenca gli agenti del team" {
  run "$OFFICE_ROOT/agents/launch.sh"
  assert_output --partial "alessio"
  assert_output --partial "stefano"
  assert_output --partial "marwen"
}

@test "iterm usa il colore del manifest" {
  run "$OFFICE_ROOT/agents/iterm.sh" --dry-run stefano
  assert_success
  assert_output --partial "4a90e2"
}

@test "iterm --dry-run all elenca una riga per agente" {
  run bash -c "'$OFFICE_ROOT/agents/iterm.sh' --dry-run all | grep -c 'agents/'"
  assert_output "3"
}

@test "dashboard elenca gli agenti del manifest" {
  "$OFFICE_ROOT/agents/setstatus.sh" stefano WORKING "Fix BUG-001"
  run "$OFFICE_ROOT/agents/dashboard.sh"
  assert_success
  assert_output --partial "Stefano"
  assert_output --partial "Fix BUG-001"
}

@test "dashboard non mostra agenti che non sono nel manifest" {
  use_manifest team-duplicates.json
  "$OFFICE_ROOT/agents/setstatus.sh" marco IDLE
  run "$OFFICE_ROOT/agents/dashboard.sh"
  refute_output --partial "Stefano"
  assert_output --partial "Marco"
}
```

- [ ] **Step 2: Esegui i test e verifica che falliscano**

Run: `./tests/run.sh tests/scripts.bats`
Expected: FAIL sui sette test nuovi.

- [ ] **Step 3: Riscrivi launch.sh**

`agents/launch.sh` diventa:

```bash
#!/usr/bin/env bash
# The Office — Launch agent
# Uso: ./agents/launch.sh [--dry-run] <agente>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/team.sh"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DRY_RUN=""
if [ "$1" = "--dry-run" ]; then
  DRY_RUN=1
  shift
fi

AGENT=$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')

if [ -z "$AGENT" ]; then
  echo "Agenti disponibili:"
  team_ids | while read -r id; do
    printf "  %-12s (%s)\n" "$id" "$(team_get "$id" label)"
  done
  echo ""
  echo "Uso: ./agents/launch.sh <agente>"
  exit 0
fi

team_validate "$AGENT" || exit 1

NAME=$(team_get "$AGENT" name)
LABEL=$(team_get "$AGENT" label)
FOLDER=$(team_get "$AGENT" folder)

WAIT_MSG="Poi rispondi con un unico messaggio di ready (es: '$NAME pronto. In attesa del via.') e NON fare nient'altro: nessuna analisi, nessun file aggiuntivo, nessuna proposta. Aspetta il primo comando esplicito."

PROMPT="Sei $NAME, $LABEL. Leggi $FOLDER/SOUL.md e $FOLDER/IDENTITY.md. Se $FOLDER/SOUL.md non esiste, scrivilo prima seguendo agents/_authoring/SOUL-AUTHORING.md e $FOLDER/ROLE-BRIEF.md. $WAIT_MSG"

if [ -n "$DRY_RUN" ]; then
  echo "$PROMPT"
  exit 0
fi

cd "$PROJECT_DIR" || exit 1
claude "$PROMPT"
```

Nota il refuso corretto rispetto all'originale: `null'altro` diventa `nient'altro`.

- [ ] **Step 4: Migra iterm.sh**

In `agents/iterm.sh`:

1. Aggiungi `source "$SCRIPT_DIR/lib/team.sh"` (lo script usa `SCRIPT_DIR` calcolato da `$0`; se manca, aggiungilo come negli altri).
2. Elimina le tre mappe `typeset -A BG`, `NAME`, `ROLE`.
3. Sostituisci gli accessi `${BG[$agent]}`, `${NAME[$agent]}`, `${ROLE[$agent]}` con:

```bash
BG_COLOR=$(team_get "$agent" color | tr -d '#')
AGENT_NAME=$(team_get "$agent" name)
AGENT_ROLE=$(team_get "$agent" label)
```

4. Sostituisci l'espansione di `all` con `team_ids`.
5. Aggiungi il supporto `--dry-run`: quando attivo, stampa una riga per agente nel formato `<nome> <colore> <folder>` invece di invocare `osascript`.

Poiché `iterm.sh` è uno script `zsh`, verifica che `team.sh` sia compatibile: usa solo costrutti POSIX e `local`, che zsh supporta. Se `BASH_SOURCE` non è disponibile in zsh, sostituisci in `team.sh` la riga di `TEAM_LIB_DIR` con:

```bash
TEAM_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
```

- [ ] **Step 5: Migra dashboard.sh e live-dashboard.sh**

In entrambi:

1. `source "$SCRIPT_DIR/lib/team.sh"`.
2. `SHARED_DIR="${OFFICE_SHARED_DIR:-$SCRIPT_DIR/../shared-context}"` e usalo per `AGENT-STATUS.json` e `queues/`.
3. Sostituisci l'elenco fisso di agenti con un ciclo su `team_ids`, prendendo il nome visualizzato da `team_get "$id" name` e l'etichetta da `team_get "$id" label`.
4. Un agente presente in `AGENT-STATUS.json` ma assente dal manifest non viene mostrato: il manifest è la verità.

- [ ] **Step 6: Esegui l'intera suite**

Run: `./tests/run.sh`
Expected: tutti i test PASS.

- [ ] **Step 7: Commit**

```bash
git add agents/launch.sh agents/iterm.sh agents/dashboard.sh agents/live-dashboard.sh tests/scripts.bats
git commit -m "refactor: launch, iterm e dashboard leggono il team dal manifest"
```

---

## Task 8: Libreria del catalogo e generazione

**Files:**
- Create: `agents/lib/roster.sh`
- Test: `tests/roster-lib.bats`

**Interfaces:**
- Consumes: `catalog/roles.json` (Task 2), `catalog/templates/`, `catalog/souls/` (Task 3).
- Produces:
  - `roster_catalog_path` → percorso di `roles.json`, sovrascrivibile con `OFFICE_CATALOG_FILE`
  - `roster_slugs` → uno slug per riga
  - `roster_coordinator_slugs` → solo i coordinatori
  - `roster_role_get <slug> <campo>` → `label|category|mission|log|logTemplate|tension|coordinator`; per `can`, `cannot`, `collaborates` stampa una voce per riga; return 1 se lo slug non esiste
  - `roster_choices` → una riga per ruolo nel formato `Categoria · Label\tslug`, per alimentare `gum filter`
  - `roster_id_from_name <nome>` → l'id normalizzato (lowercase, senza accenti né spazi)
  - `roster_generate_person <slug> <nome> <id> <dest_agents_dir> <team_json>` → crea la cartella persona con i cinque file
  - `roster_next_color <team_json>` → un colore esadecimale non ancora usato

- [ ] **Step 1: Scrivi i test**

Crea `tests/roster-lib.bats`:

```bash
#!/usr/bin/env bats

load 'helpers/setup'

setup() {
  setup_office_test
  source "$OFFICE_ROOT/agents/lib/roster.sh"
  DEST="$OFFICE_TEST_DIR/agents"
  mkdir -p "$DEST"
}
teardown() { teardown_office_test; }

@test "roster_slugs elenca tutti i ruoli del catalogo" {
  run bash -c "source '$OFFICE_ROOT/agents/lib/roster.sh'; roster_slugs | wc -l | tr -d ' '"
  [ "$output" -ge 34 ]
}

@test "roster_role_get restituisce la label" {
  run roster_role_get backend label
  assert_success
  assert_output "Backend Engineer"
}

@test "roster_role_get su uno slug inesistente fallisce" {
  run roster_role_get inventato label
  assert_failure
}

@test "roster_role_get su can stampa una voce per riga" {
  run bash -c "source '$OFFICE_ROOT/agents/lib/roster.sh'; roster_role_get backend can | wc -l | tr -d ' '"
  [ "$output" -ge 2 ]
}

@test "roster_coordinator_slugs contiene ceo e pm" {
  run roster_coordinator_slugs
  assert_output --partial "ceo"
  assert_output --partial "pm"
}

@test "roster_coordinator_slugs non contiene ruoli non coordinatori" {
  run roster_coordinator_slugs
  refute_output --partial "backend"
}

@test "roster_id_from_name normalizza il nome" {
  run roster_id_from_name "Niccolò"
  assert_output "niccolo"
  run roster_id_from_name "Maria Grazia"
  assert_output "mariagrazia"
  run roster_id_from_name "STEFANO"
  assert_output "stefano"
}

@test "roster_choices produce righe con categoria, label e slug" {
  run bash -c "source '$OFFICE_ROOT/agents/lib/roster.sh'; roster_choices | grep 'backend'"
  assert_output --partial "Engineering"
  assert_output --partial "Backend Engineer"
}

@test "roster_generate_person crea i file attesi" {
  echo '{"version":1,"team":[]}' > "$OFFICE_SHARED_DIR/TEAM.json"
  roster_generate_person backend "Marco" marco "$DEST" "$OFFICE_SHARED_DIR/TEAM.json"
  [ -f "$DEST/marco/IDENTITY.md" ]
  [ -f "$DEST/marco/HEARTBEAT.md" ]
  [ -f "$DEST/marco/ROLE-BRIEF.md" ]
  [ -f "$DEST/marco/BUILD-LOG.md" ]
}

@test "roster_generate_person non crea SOUL.md per un ruolo senza anima nel catalogo" {
  echo '{"version":1,"team":[]}' > "$OFFICE_SHARED_DIR/TEAM.json"
  roster_generate_person backend "Marco" marco "$DEST" "$OFFICE_SHARED_DIR/TEAM.json"
  [ ! -f "$DEST/marco/SOUL.md" ]
}

@test "roster_generate_person copia SOUL.md per un ruolo storico" {
  echo '{"version":1,"team":[]}' > "$OFFICE_SHARED_DIR/TEAM.json"
  roster_generate_person tester "Marwen" marwen "$DEST" "$OFFICE_SHARED_DIR/TEAM.json"
  [ -f "$DEST/marwen/SOUL.md" ]
  run grep -q "Marwen" "$DEST/marwen/SOUL.md"
  assert_success
  run grep -q "__AGENT_NAME__" "$DEST/marwen/SOUL.md"
  assert_failure
}

@test "roster_generate_person non crea un log per un ruolo senza log" {
  echo '{"version":1,"team":[]}' > "$OFFICE_SHARED_DIR/TEAM.json"
  roster_generate_person ceo "Alessio" alessio "$DEST" "$OFFICE_SHARED_DIR/TEAM.json"
  [ -f "$DEST/alessio/IDENTITY.md" ]
  run bash -c "ls '$DEST/alessio/' | grep -i 'log'"
  assert_failure
}

@test "IDENTITY.md contiene i confini e l'attrito del ruolo" {
  echo '{"version":1,"team":[]}' > "$OFFICE_SHARED_DIR/TEAM.json"
  roster_generate_person backend "Marco" marco "$DEST" "$OFFICE_SHARED_DIR/TEAM.json"
  run grep -q "Marco" "$DEST/marco/IDENTITY.md"
  assert_success
  run grep -qi "non pu" "$DEST/marco/IDENTITY.md"
  assert_success
  run grep -qi "attrito" "$DEST/marco/IDENTITY.md"
  assert_success
}

@test "roster_next_color evita i colori già in uso" {
  cp "$OFFICE_ROOT/tests/fixtures/team-valid.json" "$OFFICE_SHARED_DIR/TEAM.json"
  run roster_next_color "$OFFICE_SHARED_DIR/TEAM.json"
  assert_success
  refute_output "#f5b400"
  refute_output "#4a90e2"
  refute_output "#2ecc71"
}
```

- [ ] **Step 2: Esegui i test e verifica che falliscano**

Run: `./tests/run.sh tests/roster-lib.bats`
Expected: FAIL — `agents/lib/roster.sh` non esiste.

- [ ] **Step 3: Scrivi la libreria**

Crea `agents/lib/roster.sh`:

```bash
#!/usr/bin/env bash
# roster.sh — accesso al catalogo dei ruoli e generazione delle cartelle persona.
# Serve solo a setup.sh e hire.sh. Gli script di uso quotidiano caricano team.sh.

ROSTER_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROSTER_ROOT="$(cd "$ROSTER_LIB_DIR/../.." && pwd)"

roster_catalog_path() {
  if [ -n "$OFFICE_CATALOG_FILE" ]; then
    echo "$OFFICE_CATALOG_FILE"
  else
    echo "$ROSTER_ROOT/catalog/roles.json"
  fi
}

roster_catalog_dir() {
  dirname "$(roster_catalog_path)"
}

roster_require_catalog() {
  local catalog
  catalog="$(roster_catalog_path)"
  if [ ! -f "$catalog" ]; then
    echo "Errore: catalogo dei ruoli non trovato in $catalog." >&2
    exit 2
  fi
  if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$catalog" >/dev/null 2>&1; then
    echo "Errore: $catalog non è un JSON valido." >&2
    exit 2
  fi
}

roster_slugs() {
  roster_require_catalog
  python3 - "$(roster_catalog_path)" <<'PY' 2>/dev/null
import json, sys
for r in json.load(open(sys.argv[1]))["roles"]:
    print(r["slug"])
PY
}

roster_coordinator_slugs() {
  roster_require_catalog
  python3 - "$(roster_catalog_path)" <<'PY' 2>/dev/null
import json, sys
for r in json.load(open(sys.argv[1]))["roles"]:
    if r.get("coordinator"):
        print(r["slug"])
PY
}

roster_role_get() {
  local slug="$1" field="$2"
  roster_require_catalog
  python3 - "$(roster_catalog_path)" "$slug" "$field" <<'PY' 2>/dev/null
import json, sys
path, slug, field = sys.argv[1], sys.argv[2], sys.argv[3]
for r in json.load(open(path))["roles"]:
    if r["slug"] == slug:
        v = r.get(field)
        if v is None:
            print("")
        elif isinstance(v, bool):
            print("true" if v else "false")
        elif isinstance(v, list):
            for item in v:
                print(item)
        else:
            print(v)
        sys.exit(0)
sys.exit(1)
PY
}

# Righe "Categoria · Label<TAB>slug" per gum filter.
roster_choices() {
  roster_require_catalog
  python3 - "$(roster_catalog_path)" <<'PY' 2>/dev/null
import json, sys
for r in json.load(open(sys.argv[1]))["roles"]:
    print(f"{r['category']} · {r['label']}\t{r['slug']}")
PY
}

roster_coordinator_choices() {
  roster_require_catalog
  python3 - "$(roster_catalog_path)" <<'PY' 2>/dev/null
import json, sys
for r in json.load(open(sys.argv[1]))["roles"]:
    if r.get("coordinator"):
        print(f"{r['label']}\t{r['slug']}")
PY
}

roster_id_from_name() {
  python3 - "$1" <<'PY'
import sys, unicodedata, re
name = unicodedata.normalize("NFKD", sys.argv[1])
name = "".join(c for c in name if not unicodedata.combining(c))
print(re.sub(r"[^a-z0-9]", "", name.lower()))
PY
}

# Palette di riserva per i nuovi assunti, in ordine di preferenza.
ROSTER_PALETTE="#f5b400 #4a90e2 #9b59b6 #e74c3c #1abc9c #2ecc71 #e67e22 #3498db #8e44ad #16a085 #d35400 #27ae60"

roster_next_color() {
  local team_json="$1"
  local used color
  used=$(python3 - "$team_json" <<'PY' 2>/dev/null
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
for m in data.get("team", []):
    print(m.get("color", ""))
PY
)
  for color in $ROSTER_PALETTE; do
    if ! echo "$used" | grep -qx -- "$color"; then
      echo "$color"
      return 0
    fi
  done
  # Palette esaurita: genera un colore deterministico dal numero di membri.
  python3 - "$team_json" <<'PY'
import json, sys, colorsys
try:
    n = len(json.load(open(sys.argv[1])).get("team", []))
except Exception:
    n = 0
r, g, b = colorsys.hsv_to_rgb((n * 0.37) % 1.0, 0.65, 0.85)
print("#%02x%02x%02x" % (int(r * 255), int(g * 255), int(b * 255)))
PY
}

# Sostituisce i segnaposto in un template e scrive il risultato.
_roster_render() {
  local src="$1" dest="$2" name="$3" label="$4"
  python3 - "$src" "$dest" "$name" "$label" <<'PY'
import sys
src, dest, name, label = sys.argv[1:5]
text = open(src).read()
text = text.replace("__AGENT_NAME__", name).replace("__ROLE_LABEL__", label)
open(dest, "w").write(text)
PY
}

# roster_generate_person <slug> <nome> <id> <dest_agents_dir> <team_json>
roster_generate_person() {
  local slug="$1" name="$2" id="$3" dest_dir="$4" team_json="$5"
  roster_require_catalog

  local label category mission log log_template tension
  label=$(roster_role_get "$slug" label) || return 1
  category=$(roster_role_get "$slug" category)
  mission=$(roster_role_get "$slug" mission)
  log=$(roster_role_get "$slug" log)
  log_template=$(roster_role_get "$slug" logTemplate)
  tension=$(roster_role_get "$slug" tension)

  local person_dir="$dest_dir/$id"
  mkdir -p "$person_dir"

  local catalog_dir
  catalog_dir="$(roster_catalog_dir)"

  # IDENTITY.md — interamente derivato dai dati.
  {
    echo "# $name — Identity"
    echo ""
    echo "## Nome"
    echo "$name"
    echo ""
    echo "## Ruolo"
    echo "$label ($category)"
    echo ""
    echo "## Missione"
    echo "$mission"
    echo ""
    echo "## Cosa può fare"
    roster_role_get "$slug" can | while read -r line; do
      [ -n "$line" ] && echo "- $line"
    done
    echo ""
    echo "## Cosa non può fare"
    roster_role_get "$slug" cannot | while read -r line; do
      [ -n "$line" ] && echo "- $line"
    done
    echo ""
    echo "## Lavora con"
    roster_role_get "$slug" collaborates | while read -r other; do
      [ -n "$other" ] && echo "- $(roster_role_get "$other" label)"
    done
    echo ""
    echo "## Attrito dichiarato"
    echo "$tension"
    echo ""
    echo "## Comunicazione"
    echo ""
    echo "Invia un messaggio:"
    echo '```'
    echo "./agents/msg.sh $id <destinatario> \"testo\""
    echo '```'
    echo ""
    echo "Controlla l'inbox:"
    echo '```'
    echo "ls shared-context/inbox/$id/"
    echo '```'
    echo ""
    echo "Conferma ricezione:"
    echo '```'
    echo "./agents/ack.sh <msg-id> $id"
    echo '```'
    echo ""
    echo "**Regola:** ACK ogni messaggio ricevuto prima di rispondere."
  } > "$person_dir/IDENTITY.md"

  # HEARTBEAT.md
  _roster_render "$catalog_dir/templates/heartbeat.md" "$person_dir/HEARTBEAT.md" "$name" "$label"

  # ROLE-BRIEF.md
  {
    echo "# $label — Role Brief"
    echo ""
    echo "Dati del ruolo dal catalogo. Servono a scrivere il SOUL.md se manca."
    echo ""
    echo "- **Slug:** $slug"
    echo "- **Categoria:** $category"
    echo "- **Missione:** $mission"
    echo "- **Attrito:** $tension"
    echo ""
    echo "## Può"
    roster_role_get "$slug" can | while read -r line; do
      [ -n "$line" ] && echo "- $line"
    done
    echo ""
    echo "## Non può"
    roster_role_get "$slug" cannot | while read -r line; do
      [ -n "$line" ] && echo "- $line"
    done
  } > "$person_dir/ROLE-BRIEF.md"

  # Log di ruolo, se previsto.
  if [ -n "$log" ] && [ -n "$log_template" ]; then
    _roster_render "$catalog_dir/templates/$log_template.md" "$person_dir/$log" "$name" "$label"
  fi

  # SOUL.md, solo se il catalogo ne ha una scritta.
  if [ -f "$catalog_dir/souls/$slug.md" ]; then
    _roster_render "$catalog_dir/souls/$slug.md" "$person_dir/SOUL.md" "$name" "$label"
  fi
}
```

- [ ] **Step 4: Esegui i test e verifica che passino**

Run: `./tests/run.sh tests/roster-lib.bats`
Expected: 14 test PASS.

- [ ] **Step 5: Commit**

```bash
git add agents/lib/roster.sh tests/roster-lib.bats
git commit -m "feat: libreria roster.sh per catalogo e generazione delle cartelle persona"
```

---

## Task 9: Wizard non interattivo

**Files:**
- Modify: `setup.sh` (riscritto)
- Test: `tests/setup-wizard.bats`

**Interfaces:**
- Consumes: `roster_generate_person`, `roster_role_get`, `roster_next_color`, `roster_id_from_name` da Task 8.
- Produces: `setup.sh --config <file>` genera un progetto completo senza TUI. Formato del file di config:

```json
{
  "project": { "name": "flow", "description": "...", "stack": "Laravel, Vue", "brand": "Flow" },
  "team": [
    { "role": "pm", "name": "Giulia" },
    { "role": "backend", "name": "Marco" }
  ]
}
```

La prima voce di `team` deve avere `coordinator: true` nel catalogo, altrimenti errore ed exit 2.

- [ ] **Step 1: Scrivi i test del wizard**

Crea `tests/setup-wizard.bats`:

```bash
#!/usr/bin/env bats

load 'helpers/setup'

setup() {
  setup_office_test
  TARGET="$OFFICE_TEST_DIR/progetto"
  CONFIG="$OFFICE_TEST_DIR/config.json"
  cat > "$CONFIG" <<'JSON'
{
  "project": { "name": "flow", "description": "Un progetto di prova", "stack": "Laravel, Vue", "brand": "Flow" },
  "team": [
    { "role": "pm", "name": "Giulia" },
    { "role": "backend", "name": "Marco" },
    { "role": "backend", "name": "Luca" },
    { "role": "tester", "name": "Marwen" }
  ]
}
JSON
}
teardown() { teardown_office_test; }

@test "il wizard genera la struttura del progetto" {
  run "$OFFICE_ROOT/setup.sh" --config "$CONFIG" --target "$TARGET"
  assert_success
  [ -d "$TARGET/agents" ]
  [ -d "$TARGET/shared-context" ]
  [ -f "$TARGET/CLAUDE.md" ]
  [ -f "$TARGET/AGENTS.md" ]
}

@test "il wizard crea una cartella per persona" {
  "$OFFICE_ROOT/setup.sh" --config "$CONFIG" --target "$TARGET"
  [ -d "$TARGET/agents/giulia" ]
  [ -d "$TARGET/agents/marco" ]
  [ -d "$TARGET/agents/luca" ]
  [ -d "$TARGET/agents/marwen" ]
}

@test "il wizard scrive TEAM.json con tutte le persone" {
  "$OFFICE_ROOT/setup.sh" --config "$CONFIG" --target "$TARGET"
  run python3 -c "import json,sys; print(' '.join(m['id'] for m in json.load(open(sys.argv[1]))['team']))" "$TARGET/shared-context/TEAM.json"
  assert_output "giulia marco luca marwen"
}

@test "il primo membro è marcato coordinator" {
  "$OFFICE_ROOT/setup.sh" --config "$CONFIG" --target "$TARGET"
  run python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['team'][0]['coordinator'])" "$TARGET/shared-context/TEAM.json"
  assert_output "True"
}

@test "i colori assegnati sono tutti diversi" {
  "$OFFICE_ROOT/setup.sh" --config "$CONFIG" --target "$TARGET"
  run python3 -c "
import json,sys
colors=[m['color'] for m in json.load(open(sys.argv[1]))['team']]
print('ok' if len(set(colors))==len(colors) else 'duplicati')
" "$TARGET/shared-context/TEAM.json"
  assert_output "ok"
}

@test "il wizard copia gli script e le librerie" {
  "$OFFICE_ROOT/setup.sh" --config "$CONFIG" --target "$TARGET"
  [ -x "$TARGET/agents/msg.sh" ]
  [ -x "$TARGET/agents/setstatus.sh" ]
  [ -x "$TARGET/agents/hire.sh" ]
  [ -f "$TARGET/agents/lib/team.sh" ]
  [ -f "$TARGET/agents/lib/roster.sh" ]
}

@test "il wizard copia il catalogo ma non tutte le anime" {
  "$OFFICE_ROOT/setup.sh" --config "$CONFIG" --target "$TARGET"
  [ -f "$TARGET/catalog/roles.json" ]
  [ ! -d "$TARGET/catalog/souls" ]
}

@test "il wizard copia le istruzioni di authoring" {
  "$OFFICE_ROOT/setup.sh" --config "$CONFIG" --target "$TARGET"
  [ -f "$TARGET/agents/_authoring/SOUL-AUTHORING.md" ]
}

@test "un ruolo storico riceve la sua anima, uno nuovo no" {
  "$OFFICE_ROOT/setup.sh" --config "$CONFIG" --target "$TARGET"
  [ -f "$TARGET/agents/marwen/SOUL.md" ]
  [ ! -f "$TARGET/agents/marco/SOUL.md" ]
  [ -f "$TARGET/agents/marco/ROLE-BRIEF.md" ]
}

@test "gli script generati funzionano sul team generato" {
  "$OFFICE_ROOT/setup.sh" --config "$CONFIG" --target "$TARGET"
  run env OFFICE_SHARED_DIR="$TARGET/shared-context" "$TARGET/agents/setstatus.sh" luca WORKING "API pagamenti"
  assert_success
  run env OFFICE_SHARED_DIR="$TARGET/shared-context" "$TARGET/agents/setstatus.sh" stefano IDLE
  assert_failure
}

@test "il wizard rifiuta una config senza coordinatore" {
  cat > "$CONFIG" <<'JSON'
{
  "project": { "name": "flow", "description": "x", "stack": "y", "brand": "z" },
  "team": [ { "role": "backend", "name": "Marco" } ]
}
JSON
  run "$OFFICE_ROOT/setup.sh" --config "$CONFIG" --target "$TARGET"
  [ "$status" -eq 2 ]
  assert_output --partial "coordinamento"
}

@test "il wizard rifiuta un ruolo fuori catalogo" {
  cat > "$CONFIG" <<'JSON'
{
  "project": { "name": "flow", "description": "x", "stack": "y", "brand": "z" },
  "team": [ { "role": "pm", "name": "Giulia" }, { "role": "astronauta", "name": "Marco" } ]
}
JSON
  run "$OFFICE_ROOT/setup.sh" --config "$CONFIG" --target "$TARGET"
  [ "$status" -eq 2 ]
  assert_output --partial "astronauta"
}

@test "il wizard rifiuta due persone con lo stesso id" {
  cat > "$CONFIG" <<'JSON'
{
  "project": { "name": "flow", "description": "x", "stack": "y", "brand": "z" },
  "team": [ { "role": "pm", "name": "Giulia" }, { "role": "backend", "name": "giulia" } ]
}
JSON
  run "$OFFICE_ROOT/setup.sh" --config "$CONFIG" --target "$TARGET"
  [ "$status" -eq 2 ]
  assert_output --partial "giulia"
}

@test "il wizard rifiuta un team vuoto" {
  cat > "$CONFIG" <<'JSON'
{ "project": { "name": "flow", "description": "x", "stack": "y", "brand": "z" }, "team": [] }
JSON
  run "$OFFICE_ROOT/setup.sh" --config "$CONFIG" --target "$TARGET"
  [ "$status" -eq 2 ]
}

@test "CLAUDE.md generato elenca il team reale" {
  "$OFFICE_ROOT/setup.sh" --config "$CONFIG" --target "$TARGET"
  run grep -q "Giulia" "$TARGET/CLAUDE.md"
  assert_success
  run grep -q "Luca" "$TARGET/CLAUDE.md"
  assert_success
  run grep -q "Alessandra" "$TARGET/CLAUDE.md"
  assert_failure
}
```

- [ ] **Step 2: Esegui i test e verifica che falliscano**

Run: `./tests/run.sh tests/setup-wizard.bats`
Expected: FAIL — `setup.sh` non conosce `--config`.

- [ ] **Step 3: Riscrivi setup.sh, percorso non interattivo**

Riscrivi `setup.sh` con questa struttura. In questo task implementa solo il percorso `--config`; le schermate gum arrivano in Task 10, dove `wizard_collect_interactive` viene riempita.

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/agents/lib/roster.sh"

CONFIG_FILE=""
TARGET_DIR=""
SAVE_CONFIG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --config)      CONFIG_FILE="$2"; shift 2 ;;
    --target)      TARGET_DIR="$2"; shift 2 ;;
    --save-config) SAVE_CONFIG="$2"; shift 2 ;;
    -h|--help)
      echo "Uso: ./setup.sh [--config <file>] [--target <dir>] [--save-config <file>]"
      exit 0 ;;
    *) echo "Opzione sconosciuta: $1" >&2; exit 2 ;;
  esac
done

# ── Validazione della configurazione ──────────────────────────────────────────
# Verifica: team non vuoto, primo membro coordinatore, ruoli esistenti, id univoci.
validate_config() {
  local config="$1"
  python3 - "$config" "$(roster_catalog_path)" <<'PY'
import json, sys, unicodedata, re

config_path, catalog_path = sys.argv[1], sys.argv[2]

try:
    config = json.load(open(config_path))
except Exception as e:
    print(f"Errore: config non valida ({e}).", file=sys.stderr)
    sys.exit(2)

roles = {r["slug"]: r for r in json.load(open(catalog_path))["roles"]}
team = config.get("team", [])

if not team:
    print("Errore: il team è vuoto. Serve almeno una persona.", file=sys.stderr)
    sys.exit(2)

def to_id(name):
    n = unicodedata.normalize("NFKD", name)
    n = "".join(c for c in n if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]", "", n.lower())

for m in team:
    if m.get("role") not in roles:
        print(f"Errore: ruolo '{m.get('role')}' non presente nel catalogo.", file=sys.stderr)
        sys.exit(2)
    if not m.get("name"):
        print("Errore: ogni persona deve avere un nome.", file=sys.stderr)
        sys.exit(2)

if not roles[team[0]["role"]].get("coordinator"):
    print("Errore: la prima persona deve avere un ruolo di coordinamento.", file=sys.stderr)
    print("Ruoli validi: " + ", ".join(s for s, r in roles.items() if r.get("coordinator")), file=sys.stderr)
    sys.exit(2)

seen = {}
for m in team:
    i = to_id(m["name"])
    if i in seen:
        print(f"Errore: due persone producono lo stesso id '{i}' ({seen[i]} e {m['name']}).", file=sys.stderr)
        sys.exit(2)
    seen[i] = m["name"]
PY
}

# ── Raccolta della configurazione ─────────────────────────────────────────────
if [ -n "$CONFIG_FILE" ]; then
  [ -f "$CONFIG_FILE" ] || { echo "Errore: $CONFIG_FILE non trovato." >&2; exit 2; }
  validate_config "$CONFIG_FILE"
else
  wizard_collect_interactive   # definita in Task 10; scrive $CONFIG_FILE
fi

if [ -z "$TARGET_DIR" ]; then
  TARGET_DIR=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['project'].get('target',''))" "$CONFIG_FILE")
fi
[ -n "$TARGET_DIR" ] || { echo "Errore: directory di destinazione non specificata (--target)." >&2; exit 2; }

PROJECT_NAME=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['project']['name'])" "$CONFIG_FILE")
PROJECT_DESC=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['project']['description'])" "$CONFIG_FILE")
TECH_STACK=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['project']['stack'])" "$CONFIG_FILE")
BRAND_NAME=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['project']['brand'])" "$CONFIG_FILE")

# ── Struttura ─────────────────────────────────────────────────────────────────
mkdir -p "$TARGET_DIR/agents/lib" "$TARGET_DIR/agents/_authoring" \
         "$TARGET_DIR/shared-context/inbox" "$TARGET_DIR/shared-context/queues" \
         "$TARGET_DIR/catalog" "$TARGET_DIR/docs/sessions"

# ── shared-context ────────────────────────────────────────────────────────────
# Copia qui, invariati, i tre heredoc THESIS.md / ROADMAP.md / BRAND-GUIDE.md
# che nella versione precedente di setup.sh stanno alle righe 112-195
# (recuperabili con: git show HEAD~1:setup.sh | sed -n '112,195p').
# Usano $PROJECT_DESC, $PROJECT_NAME, $TECH_STACK e $BRAND_NAME, tutti
# già valorizzati sopra, quindi funzionano senza modifiche.

# ── Persone e manifest ────────────────────────────────────────────────────────
echo '{"version":1,"team":[]}' > "$TARGET_DIR/shared-context/TEAM.json"

COUNT=$(python3 -c "import json,sys; print(len(json.load(open(sys.argv[1]))['team']))" "$CONFIG_FILE")
i=0
while [ "$i" -lt "$COUNT" ]; do
  SLUG=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['team'][$i]['role'])" "$CONFIG_FILE")
  NAME=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['team'][$i]['name'])" "$CONFIG_FILE")
  ID=$(roster_id_from_name "$NAME")
  COLOR=$(roster_next_color "$TARGET_DIR/shared-context/TEAM.json")

  roster_generate_person "$SLUG" "$NAME" "$ID" "$TARGET_DIR/agents" "$TARGET_DIR/shared-context/TEAM.json"

  LABEL=$(roster_role_get "$SLUG" label)
  LOG=$(roster_role_get "$SLUG" log)
  COORD=$(roster_role_get "$SLUG" coordinator)

  python3 - "$TARGET_DIR/shared-context/TEAM.json" "$ID" "$NAME" "$SLUG" "$LABEL" "$LOG" "$COLOR" "$COORD" <<'PY'
import json, os, sys
path, id_, name, role, label, log, color, coord = sys.argv[1:9]
data = json.load(open(path))
data["team"].append({
    "id": id_, "name": name, "role": role, "label": label,
    "folder": f"agents/{id_}", "log": log or None,
    "color": color, "coordinator": coord == "true",
})
tmp = path + ".tmp"
json.dump(data, open(tmp, "w"), indent=2, ensure_ascii=False)
os.replace(tmp, path)
PY

  mkdir -p "$TARGET_DIR/shared-context/inbox/$ID"
  echo "[]" > "$TARGET_DIR/shared-context/queues/$ID.json"

  i=$((i + 1))
done

# ── Script, librerie, catalogo ────────────────────────────────────────────────
for s in msg.sh ack.sh setstatus.sh qtask.sh with-status.sh launch.sh iterm.sh \
         dashboard.sh live-dashboard.sh hire.sh; do
  cp "$SCRIPT_DIR/agents/$s" "$TARGET_DIR/agents/$s"
  chmod +x "$TARGET_DIR/agents/$s"
done

cp "$SCRIPT_DIR/agents/lib/team.sh"   "$TARGET_DIR/agents/lib/team.sh"
cp "$SCRIPT_DIR/agents/lib/roster.sh" "$TARGET_DIR/agents/lib/roster.sh"
cp -r "$SCRIPT_DIR/catalog/templates" "$TARGET_DIR/catalog/templates"
cp "$SCRIPT_DIR/catalog/roles.json"   "$TARGET_DIR/catalog/roles.json"
cp "$SCRIPT_DIR/catalog/SOUL-AUTHORING.md" "$TARGET_DIR/agents/_authoring/SOUL-AUTHORING.md"

# catalog/souls/ NON viene copiato: le anime dei ruoli scelti sono già state
# scritte nelle cartelle persona da roster_generate_person.

# ── CLAUDE.md, AGENTS.md, GEMINI.md ───────────────────────────────────────────
generate_agent_docs "$TARGET_DIR"   # definita sotto

if [ -n "$SAVE_CONFIG" ]; then
  cp "$CONFIG_FILE" "$SAVE_CONFIG"
fi

echo "✓ Progetto generato in $TARGET_DIR"
```

Definisci `generate_agent_docs` prima del suo uso, subito dopo `validate_config`:

```bash
# Emette l'elenco del team in markdown, una voce per persona.
_team_roster_markdown() {
  local team_json="$1"
  python3 - "$team_json" "$(roster_catalog_path)" <<'PY'
import json, sys
team = json.load(open(sys.argv[1]))["team"]
roles = {r["slug"]: r for r in json.load(open(sys.argv[2]))["roles"]}
for m in team:
    r = roles[m["role"]]
    print(f"### {m['name']} — {m['label']}")
    print(f"- **Missione:** {r['mission']}")
    print(f"- **Può:** {r['can'][0]}")
    print(f"- **Non può:** {r['cannot'][0]}")
    print(f"- **Attrito:** {r['tension']}")
    print(f"- **Config:** {m['folder']}/")
    print()
PY
}

generate_agent_docs() {
  local target="$1"
  local roster
  roster="$(_team_roster_markdown "$target/shared-context/TEAM.json")"

  cat > "$target/CLAUDE.md" <<EOF
# CLAUDE.md — $PROJECT_NAME

## Progetto
$PROJECT_DESC

**Stack:** $TECH_STACK

## Sistema multi-agente

Questo progetto usa un sistema multi-agente. Il team è descritto in
\`shared-context/TEAM.json\`: quello è l'elenco autorevole, questa sezione ne è
il riassunto leggibile. Gli script validano gli agenti contro il manifest.

$roster

## Contesto condiviso
Letto da tutti: \`shared-context/THESIS.md\`, \`ROADMAP.md\`, \`BRAND-GUIDE.md\`.

## Regole
1. Ogni agente resta nel suo dominio, definito in \`IDENTITY.md\`.
2. I disaccordi sono un bene: ogni ruolo ha un attrito dichiarato ed è tenuto a usarlo.
3. Ogni agente legge SOUL.md e IDENTITY.md all'inizio della sessione.
   Se SOUL.md non esiste, lo scrive seguendo \`agents/_authoring/SOUL-AUTHORING.md\`.
4. HEARTBEAT.md va aggiornato a fine sessione.
5. In caso di dubbio, \`shared-context/THESIS.md\`.

## Comandi
\`\`\`bash
./agents/launch.sh <agente>       # avvia un agente
./agents/iterm.sh <agente|all>    # finestre iTerm2 dedicate
./agents/setstatus.sh <agente> <WORKING|IDLE|STANDBY> ["task"]
./agents/msg.sh <da> <a> "<testo>"
./agents/ack.sh <msg-id> <agente>
./agents/qtask.sh <add|done|list> <agente> [...]
./agents/dashboard.sh             # stato del team
./agents/hire.sh                  # aggiungi una persona
\`\`\`

## Sessioni
Un file al giorno: \`docs/sessions/YYYY-MM-DD-session.md\`. Ogni agente aggiorna
solo la propria sezione.
EOF

  cat > "$target/AGENTS.md" <<EOF
# AGENTS.md — $PROJECT_NAME
# Cursor, Copilot, Windsurf, Codex, Devin, Replit

## Istruzioni

Fai parte di un team multi-agente. Prima di qualsiasi cosa, carica il tuo ruolo.

### 1. Identifica il ruolo
Il team è in \`shared-context/TEAM.json\`. Trova la tua voce e usa il campo
\`folder\` per sapere dove stanno i tuoi file.

$roster

### 2. Carica il contesto
- \`<folder>/SOUL.md\` — come pensi. Se manca, scrivilo seguendo
  \`agents/_authoring/SOUL-AUTHORING.md\` e \`<folder>/ROLE-BRIEF.md\`.
- \`<folder>/IDENTITY.md\` — i tuoi confini di accesso, vincolanti
- \`<folder>/HEARTBEAT.md\` — su cosa stavi lavorando
- \`shared-context/THESIS.md\` — la visione

### 3. Resta nel tuo dominio
I confini sono in IDENTITY.md. Rispettali.

### 4. Chiudi la sessione
Aggiorna HEARTBEAT.md e il tuo log di ruolo, se ne hai uno.
EOF

  cat > "$target/GEMINI.md" <<EOF
# GEMINI.md — $PROJECT_NAME

## Istruzioni

Fai parte di un team multi-agente. Il team è descritto in
\`shared-context/TEAM.json\`; ogni persona ha una cartella indicata dal campo
\`folder\`, con SOUL.md (come pensa), IDENTITY.md (cosa può toccare) e
HEARTBEAT.md (a che punto è).

$roster

## Avvio
1. Trova la tua voce in \`shared-context/TEAM.json\`
2. Leggi SOUL.md e IDENTITY.md nella tua cartella. Se SOUL.md manca, scrivilo
   seguendo \`agents/_authoring/SOUL-AUTHORING.md\`
3. Leggi \`shared-context/THESIS.md\`
4. Resta nei confini di IDENTITY.md
5. A fine sessione aggiorna HEARTBEAT.md
EOF
}
```

Il test "CLAUDE.md generato elenca il team reale" verifica proprio questo: il documento nomina Giulia e Luca, e non contiene Alessandra, che nel team generato non esiste.

- [ ] **Step 4: Esegui i test**

Run: `./tests/run.sh tests/setup-wizard.bats`
Expected: tutti PASS tranne quelli che dipendono da `hire.sh` (Task 11). Se `hire.sh` non esiste ancora, il `cp` nel ciclo fallisce: crea per ora un `agents/hire.sh` con lo shebang e `exit 0`, che Task 11 sostituisce.

- [ ] **Step 5: Commit**

```bash
git add setup.sh agents/hire.sh tests/setup-wizard.bats
git commit -m "feat: setup.sh genera un progetto da un file di configurazione"
```

---

## Task 10: Le schermate gum

**Files:**
- Modify: `setup.sh` (funzione `wizard_collect_interactive` e preflight)
- Create: `agents/lib/tui.sh`
- Test: `tests/tui-lib.bats`

**Interfaces:**
- Consumes: `roster_choices`, `roster_coordinator_choices`, `roster_id_from_name` da Task 8.
- Produces:
  - `tui_require_gum` → se gum manca, spiega e propone l'installazione; ritorna 0 se disponibile, esce 2 se l'utente rifiuta
  - `tui_pick_role <header>` → stampa lo slug scelto
  - `tui_pick_coordinator` → stampa lo slug scelto tra i coordinatori
  - `tui_ask_name <suggerito>` → stampa il nome confermato
  - `tui_suggest_name <indice>` → un nome dal pool, per indice
  - `wizard_collect_interactive` → scrive un file di config temporaneo e ne assegna il percorso a `CONFIG_FILE`

- [ ] **Step 1: Scrivi i test della parte testabile**

`gum` è interattivo e non si pilota nei test; si testa quello che sta intorno. Crea `tests/tui-lib.bats`:

```bash
#!/usr/bin/env bats

load 'helpers/setup'

setup() {
  setup_office_test
  source "$OFFICE_ROOT/agents/lib/tui.sh"
}
teardown() { teardown_office_test; }

@test "tui_suggest_name restituisce nomi diversi per indici diversi" {
  a=$(tui_suggest_name 0)
  b=$(tui_suggest_name 1)
  [ -n "$a" ]
  [ -n "$b" ]
  [ "$a" != "$b" ]
}

@test "tui_suggest_name cicla oltre la fine del pool" {
  run tui_suggest_name 999
  assert_success
  [ -n "$output" ]
}

@test "tui_require_gum riporta assenza quando gum non è nel PATH" {
  run env PATH="/usr/bin:/bin" OFFICE_ASSUME_NO_GUM=1 bash -c "source '$OFFICE_ROOT/agents/lib/tui.sh'; tui_gum_available && echo si || echo no"
  assert_output "no"
}

@test "il rilevamento del gestore di pacchetti restituisce un comando noto" {
  run tui_install_hint
  assert_success
  case "$output" in
    *brew*|*apt*|*go\ install*|*"Vedi https://github.com/charmbracelet/gum"*) ;;
    *) false ;;
  esac
}
```

- [ ] **Step 2: Esegui i test e verifica che falliscano**

Run: `./tests/run.sh tests/tui-lib.bats`
Expected: FAIL — `agents/lib/tui.sh` non esiste.

- [ ] **Step 3: Scrivi la libreria TUI**

Crea `agents/lib/tui.sh`:

```bash
#!/usr/bin/env bash
# tui.sh — schermate gum condivise da setup.sh e hire.sh.

TUI_NAME_POOL="Giulia Marco Luca Sofia Matteo Chiara Andrea Elena Davide Sara Federico Martina Lorenzo Alice Simone Giorgia"

tui_suggest_name() {
  local index="$1" i=0 name
  for name in $TUI_NAME_POOL; do
    if [ "$i" -eq "$((index % 16))" ]; then
      echo "$name"
      return 0
    fi
    i=$((i + 1))
  done
  echo "Persona$((index + 1))"
}

tui_gum_available() {
  [ -z "$OFFICE_ASSUME_NO_GUM" ] && command -v gum >/dev/null 2>&1
}

tui_install_hint() {
  if command -v brew >/dev/null 2>&1; then
    echo "brew install gum"
  elif command -v apt-get >/dev/null 2>&1; then
    echo "sudo apt-get install gum"
  elif command -v go >/dev/null 2>&1; then
    echo "go install github.com/charmbracelet/gum@latest"
  else
    echo "Vedi https://github.com/charmbracelet/gum#installation"
  fi
}

tui_require_gum() {
  if tui_gum_available; then
    return 0
  fi

  local hint
  hint="$(tui_install_hint)"

  echo ""
  echo "Questo wizard usa gum per le schermate interattive."
  echo "gum è un piccolo strumento a riga di comando per menu e input:"
  echo "https://github.com/charmbracelet/gum"
  echo ""
  echo "Comando di installazione per questo sistema:"
  echo "  $hint"
  echo ""
  printf "Lo installo ora? [s/N]: "
  read -r answer

  if [ "$(echo "$answer" | tr '[:upper:]' '[:lower:]')" = "s" ]; then
    if eval "$hint"; then
      tui_gum_available && return 0
    fi
    echo "Installazione non riuscita. Installa gum a mano e rilancia." >&2
    exit 2
  fi

  echo ""
  echo "Setup annullato. Installa gum con:"
  echo "  $hint"
  echo ""
  echo "In alternativa usa la modalità non interattiva:"
  echo "  ./setup.sh --config <file.json> --target <directory>"
  exit 2
}

# tui_pick_role <header> → stampa lo slug
tui_pick_role() {
  local header="$1" line
  line=$(roster_choices | gum filter --height 18 --placeholder "cerca un ruolo…" --header "$header")
  [ -n "$line" ] || return 1
  printf '%s' "$line" | cut -f2
}

tui_pick_coordinator() {
  local line
  line=$(roster_coordinator_choices | gum choose --height 8 \
    --header "Chi coordina il lavoro degli altri? (obbligatorio)")
  [ -n "$line" ] || return 1
  printf '%s' "$line" | cut -f2
}

# tui_ask_name <suggerito> → stampa il nome
tui_ask_name() {
  gum input --value "$1" --placeholder "Nome della persona" --header "Come si chiama?"
}
```

- [ ] **Step 4: Implementa wizard_collect_interactive in setup.sh**

Aggiungi in `setup.sh`, dopo il `source` di `roster.sh`:

```bash
source "$SCRIPT_DIR/agents/lib/tui.sh"
```

E definisci la funzione:

```bash
wizard_collect_interactive() {
  tui_require_gum

  gum style --border rounded --padding "1 3" --margin "1 0" \
    "the-office — composizione del team"

  local target name desc stack brand size
  target=$(gum input --placeholder "/Users/me/Code/mio-progetto" --header "Directory di destinazione")
  [ -n "$target" ] || { echo "Directory obbligatoria." >&2; exit 2; }
  TARGET_DIR="$target"

  name=$(gum input --value "my-project" --header "Nome del progetto")
  desc=$(gum input --placeholder "Cosa fa questo progetto" --header "Descrizione breve")
  stack=$(gum input --placeholder "Laravel, Vue, MySQL" --header "Tech stack")
  brand=$(gum input --value "$name" --header "Nome brand")

  # Quante persone, validato 1-12.
  while true; do
    size=$(gum input --value "4" --header "Quante persone servono nel team? (1-12)")
    case "$size" in
      ''|*[!0-9]*) gum style --foreground 196 "Inserisci un numero." ; continue ;;
    esac
    if [ "$size" -ge 1 ] && [ "$size" -le 12 ]; then break; fi
    gum style --foreground 196 "Il team deve avere tra 1 e 12 persone."
  done

  CONFIG_FILE="$(mktemp)"
  local roles_file names_file
  roles_file="$(mktemp)"
  names_file="$(mktemp)"

  # Persona 1: sempre un ruolo di coordinamento.
  local slug person_name suggested i=0
  slug=$(tui_pick_coordinator) || { echo "Selezione annullata." >&2; exit 2; }
  suggested=$(tui_suggest_name 0)
  person_name=$(tui_ask_name "$suggested")
  echo "$slug"        >> "$roles_file"
  echo "$person_name" >> "$names_file"

  # Persone da 2 a N.
  i=1
  while [ "$i" -lt "$size" ]; do
    slug=$(tui_pick_role "Persona $((i + 1)) di $size — che ruolo ha?") \
      || { echo "Selezione annullata." >&2; exit 2; }
    suggested=$(tui_suggest_name "$i")
    person_name=$(tui_ask_name "$suggested")

    # Rifiuta un id già usato.
    local new_id existing_id dup=0
    new_id=$(roster_id_from_name "$person_name")
    while read -r existing; do
      existing_id=$(roster_id_from_name "$existing")
      [ "$existing_id" = "$new_id" ] && dup=1
    done < "$names_file"
    if [ "$dup" -eq 1 ]; then
      gum style --foreground 196 "Esiste già una persona che produce l'id '$new_id'. Scegli un altro nome."
      continue
    fi

    echo "$slug"        >> "$roles_file"
    echo "$person_name" >> "$names_file"
    i=$((i + 1))
  done

  # Scrivi la config.
  python3 - "$CONFIG_FILE" "$name" "$desc" "$stack" "$brand" "$target" "$roles_file" "$names_file" <<'PY'
import json, sys
out, name, desc, stack, brand, target, roles_f, names_f = sys.argv[1:9]
roles = [l.strip() for l in open(roles_f) if l.strip()]
names = [l.strip() for l in open(names_f) if l.strip()]
json.dump({
    "project": {"name": name, "description": desc, "stack": stack,
                "brand": brand, "target": target},
    "team": [{"role": r, "name": n} for r, n in zip(roles, names)],
}, open(out, "w"), indent=2, ensure_ascii=False)
PY

  rm -f "$roles_file" "$names_file"

  # Riepilogo e conferma.
  gum style --border rounded --padding "1 2" "Team"
  python3 - "$CONFIG_FILE" <<'PY'
import json, sys
for m in json.load(open(sys.argv[1]))["team"]:
    print(f"  {m['name']:<14} {m['role']}")
PY
  echo ""
  gum confirm "Genero il progetto in $TARGET_DIR?" || { echo "Setup annullato."; exit 0; }

  validate_config "$CONFIG_FILE"
}
```

- [ ] **Step 5: Esegui i test**

Run: `./tests/run.sh`
Expected: tutti PASS.

- [ ] **Step 6: Prova interattiva manuale**

```bash
./setup.sh
```

Verifica a mano: le schermate compaiono nell'ordine descritto, il passo del coordinatore non è saltabile, un nome duplicato viene rifiutato, e annullare al `gum confirm` non scrive nulla su disco.

- [ ] **Step 7: Commit**

```bash
git add agents/lib/tui.sh setup.sh tests/tui-lib.bats
git commit -m "feat: schermate gum del wizard con vincolo di coordinamento"
```

---

## Task 11: Aggiunta di un profilo

**Files:**
- Modify: `agents/hire.sh` (sostituisce lo stub di Task 9)
- Test: `tests/hire.bats`

**Interfaces:**
- Consumes: `roster_generate_person`, `roster_role_get`, `roster_next_color`, `roster_id_from_name` (Task 8); `tui_pick_role`, `tui_ask_name`, `tui_require_gum` (Task 10); `team_ids` (Task 4).
- Produces: `./agents/hire.sh [<ruolo> "<Nome>"]`. Senza argomenti è interattivo; con due argomenti non usa gum.

- [ ] **Step 1: Scrivi i test**

Crea `tests/hire.bats`:

```bash
#!/usr/bin/env bats

load 'helpers/setup'

setup() {
  setup_office_test
  use_manifest team-valid.json
  mkdir -p "$OFFICE_TEST_DIR/agents"
  export OFFICE_AGENTS_DIR="$OFFICE_TEST_DIR/agents"
}
teardown() { teardown_office_test; }

@test "hire aggiunge una persona al manifest" {
  run "$OFFICE_ROOT/agents/hire.sh" backend "Marco"
  assert_success
  run python3 -c "import json,sys; print(' '.join(m['id'] for m in json.load(open(sys.argv[1]))['team']))" "$OFFICE_SHARED_DIR/TEAM.json"
  assert_output "alessio stefano marwen marco"
}

@test "hire crea la cartella della persona con i file attesi" {
  "$OFFICE_ROOT/agents/hire.sh" backend "Marco"
  [ -f "$OFFICE_AGENTS_DIR/marco/IDENTITY.md" ]
  [ -f "$OFFICE_AGENTS_DIR/marco/HEARTBEAT.md" ]
  [ -f "$OFFICE_AGENTS_DIR/marco/ROLE-BRIEF.md" ]
  [ -f "$OFFICE_AGENTS_DIR/marco/BUILD-LOG.md" ]
}

@test "hire registra la persona come STANDBY" {
  "$OFFICE_ROOT/agents/hire.sh" backend "Marco"
  run python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['marco']['status'])" "$OFFICE_SHARED_DIR/AGENT-STATUS.json"
  assert_output "STANDBY"
}

@test "hire crea inbox e coda" {
  "$OFFICE_ROOT/agents/hire.sh" backend "Marco"
  [ -d "$OFFICE_SHARED_DIR/inbox/marco" ]
  [ -f "$OFFICE_SHARED_DIR/queues/marco.json" ]
}

@test "hire assegna un colore non ancora usato" {
  "$OFFICE_ROOT/agents/hire.sh" backend "Marco"
  run python3 - "$OFFICE_SHARED_DIR/TEAM.json" <<'PY'
import json, sys
colors = [m["color"] for m in json.load(open(sys.argv[1]))["team"]]
print("ok" if len(set(colors)) == len(colors) else "duplicati")
PY
  assert_output "ok"
}

@test "la persona assunta è subito usabile dagli altri script" {
  "$OFFICE_ROOT/agents/hire.sh" backend "Marco"
  run "$OFFICE_ROOT/agents/setstatus.sh" marco WORKING "Prima task"
  assert_success
}

@test "hire rifiuta un id già presente" {
  run "$OFFICE_ROOT/agents/hire.sh" backend "Stefano"
  [ "$status" -eq 2 ]
  assert_output --partial "stefano"
}

@test "hire rifiuta un ruolo fuori catalogo" {
  run "$OFFICE_ROOT/agents/hire.sh" astronauta "Marco"
  [ "$status" -eq 2 ]
  assert_output --partial "astronauta"
}

@test "un hire rifiutato non lascia tracce" {
  run "$OFFICE_ROOT/agents/hire.sh" astronauta "Marco"
  [ ! -d "$OFFICE_AGENTS_DIR/marco" ]
  run python3 -c "import json,sys; print(len(json.load(open(sys.argv[1]))['team']))" "$OFFICE_SHARED_DIR/TEAM.json"
  assert_output "3"
}

@test "hire annulla la cartella se la scrittura del manifest fallisce" {
  chmod 500 "$OFFICE_SHARED_DIR"
  run "$OFFICE_ROOT/agents/hire.sh" backend "Marco"
  chmod 700 "$OFFICE_SHARED_DIR"
  assert_failure
  [ ! -d "$OFFICE_AGENTS_DIR/marco" ]
}

@test "hire senza manifest esce con codice 2" {
  rm "$OFFICE_SHARED_DIR/TEAM.json"
  run "$OFFICE_ROOT/agents/hire.sh" backend "Marco"
  [ "$status" -eq 2 ]
  refute_output --partial "Traceback"
}

@test "hire stampa i passi successivi" {
  run "$OFFICE_ROOT/agents/hire.sh" backend "Marco"
  assert_output --partial "iterm.sh marco"
}
```

- [ ] **Step 2: Esegui i test e verifica che falliscano**

Run: `./tests/run.sh tests/hire.bats`
Expected: FAIL — `hire.sh` è ancora lo stub.

- [ ] **Step 3: Scrivi hire.sh**

Sostituisci `agents/hire.sh`:

```bash
#!/usr/bin/env bash
# hire.sh — aggiunge una persona a un team esistente.
# Uso:
#   ./agents/hire.sh                    interattivo (richiede gum)
#   ./agents/hire.sh <ruolo> "<Nome>"   diretto

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/team.sh"
source "$SCRIPT_DIR/lib/roster.sh"

SHARED_DIR="${OFFICE_SHARED_DIR:-$SCRIPT_DIR/../shared-context}"
AGENTS_DIR="${OFFICE_AGENTS_DIR:-$SCRIPT_DIR}"
TEAM_JSON="$(team_manifest_path)"

team_require_manifest

SLUG="${1:-}"
NAME="${2:-}"

if [ -z "$SLUG" ] || [ -z "$NAME" ]; then
  source "$SCRIPT_DIR/lib/tui.sh"
  tui_require_gum
  SLUG=$(tui_pick_role "Che ruolo ha la persona che stai aggiungendo?") \
    || { echo "Selezione annullata." >&2; exit 2; }
  NAME=$(tui_ask_name "")
  [ -n "$NAME" ] || { echo "Nome obbligatorio." >&2; exit 2; }
fi

# ── Validazione ───────────────────────────────────────────────────────────────
if ! roster_role_get "$SLUG" label >/dev/null 2>&1; then
  echo "Errore: ruolo '$SLUG' non presente nel catalogo." >&2
  echo "Ruoli disponibili: $(roster_slugs | tr '\n' ' ')" >&2
  exit 2
fi

ID=$(roster_id_from_name "$NAME")
if [ -z "$ID" ]; then
  echo "Errore: il nome '$NAME' non produce un id valido." >&2
  exit 2
fi

if team_ids | grep -qx -- "$ID"; then
  echo "Errore: '$ID' è già nel team." >&2
  echo "Scegli un nome diverso: gli id devono essere univoci." >&2
  exit 2
fi

# ── Rollback ──────────────────────────────────────────────────────────────────
PERSON_DIR="$AGENTS_DIR/$ID"
CREATED_DIR=""

rollback() {
  [ -n "$CREATED_DIR" ] && [ -d "$CREATED_DIR" ] && rm -rf "$CREATED_DIR"
  rm -rf "$SHARED_DIR/inbox/$ID" 2>/dev/null
  rm -f "$SHARED_DIR/queues/$ID.json" 2>/dev/null
}
trap 'rollback' EXIT

# ── 1. Cartella persona ───────────────────────────────────────────────────────
roster_generate_person "$SLUG" "$NAME" "$ID" "$AGENTS_DIR" "$TEAM_JSON" || {
  echo "Errore: generazione della cartella fallita." >&2
  exit 1
}
CREATED_DIR="$PERSON_DIR"

# ── 2. Manifest ───────────────────────────────────────────────────────────────
COLOR=$(roster_next_color "$TEAM_JSON")
LABEL=$(roster_role_get "$SLUG" label)
LOG=$(roster_role_get "$SLUG" log)
COORD=$(roster_role_get "$SLUG" coordinator)

python3 - "$TEAM_JSON" "$ID" "$NAME" "$SLUG" "$LABEL" "$LOG" "$COLOR" "$COORD" <<'PY' || { echo "Errore: scrittura di TEAM.json fallita." >&2; exit 1; }
import json, os, sys
path, id_, name, role, label, log, color, coord = sys.argv[1:9]
data = json.load(open(path))
data["team"].append({
    "id": id_, "name": name, "role": role, "label": label,
    "folder": f"agents/{id_}", "log": log or None,
    "color": color, "coordinator": coord == "true",
})
tmp = path + ".tmp"
json.dump(data, open(tmp, "w"), indent=2, ensure_ascii=False)
os.replace(tmp, path)
PY

# ── 3. Stato, inbox, coda ─────────────────────────────────────────────────────
mkdir -p "$SHARED_DIR/inbox/$ID" "$SHARED_DIR/queues"
echo "[]" > "$SHARED_DIR/queues/$ID.json"

STATUS_FILE="$SHARED_DIR/AGENT-STATUS.json"
python3 - "$STATUS_FILE" "$ID" <<'PY' || { echo "Errore: aggiornamento di AGENT-STATUS.json fallito." >&2; exit 1; }
import json, os, sys
path, id_ = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(path))
except Exception:
    data = {}
data[id_] = {"status": "STANDBY", "task": "", "ts": ""}
tmp = path + ".tmp"
json.dump(data, open(tmp, "w"), indent=2, ensure_ascii=False)
os.replace(tmp, path)
PY

# Tutto riuscito: disarma il rollback.
trap - EXIT

echo ""
echo "  ✓ $NAME ($LABEL) aggiunto al team come '$ID'"
echo ""
echo "  Restano due passi:"
echo "    1. Apri il suo terminale:  ./agents/iterm.sh $ID"
echo "    2. Avvisa il team:         ./agents/msg.sh <tu> $ID \"Benvenuto. Leggi ROLE-BRIEF.md.\""
echo ""
echo "  Il suo SOUL.md verrà scritto al primo avvio."
```

- [ ] **Step 4: Esegui i test e verifica che passino**

Run: `./tests/run.sh tests/hire.bats`
Expected: 12 test PASS.

- [ ] **Step 5: Esegui l'intera suite**

Run: `./tests/run.sh`
Expected: tutti PASS.

- [ ] **Step 6: Commit**

```bash
git add agents/hire.sh tests/hire.bats
git commit -m "feat: hire.sh aggiunge una persona a un team esistente con rollback"
```

---

## Task 12: Migrazione delle cartelle e degli slash command

**Files:**
- Move: `agents/ceo/` → `agents/alessio/`, `agents/engineer/` → `agents/stefano/`, `agents/product/` → `agents/walter/`, `agents/marketing/` → `agents/veronica/`, `agents/uiux/` → `agents/alessandra/`, `agents/tester/` → `agents/marwen/`
- Modify: `shared-context/TEAM.json`, i 9 file in `.claude/commands/`
- Create: `agents/_authoring/SOUL-AUTHORING.md` (copia dal catalogo)

**Interfaces:**
- Consumes: `shared-context/TEAM.json` da Task 5.
- Produces: nessuna interfaccia di codice. Dopo questo task ogni `folder` nel manifest punta a una cartella per persona.

- [ ] **Step 1: Sposta le cartelle**

```bash
git mv agents/ceo       agents/alessio
git mv agents/engineer  agents/stefano
git mv agents/product   agents/walter
git mv agents/marketing agents/veronica
git mv agents/uiux      agents/alessandra
git mv agents/tester    agents/marwen
```

- [ ] **Step 2: Aggiorna i percorsi nel manifest**

In `shared-context/TEAM.json` sostituisci ogni `folder`: `agents/ceo` → `agents/alessio`, `agents/engineer` → `agents/stefano`, `agents/product` → `agents/walter`, `agents/marketing` → `agents/veronica`, `agents/uiux` → `agents/alessandra`, `agents/tester` → `agents/marwen`.

- [ ] **Step 3: Copia le istruzioni di authoring**

```bash
mkdir -p agents/_authoring
cp catalog/SOUL-AUTHORING.md agents/_authoring/SOUL-AUTHORING.md
```

- [ ] **Step 4: Verifica che gli script seguano lo spostamento**

Run: `./agents/launch.sh --dry-run stefano`
Expected: il prompt contiene `agents/stefano/SOUL.md`.

Run: `./tests/run.sh`
Expected: tutti PASS.

- [ ] **Step 5: Aggiorna i sei comandi di ruolo**

In ognuno di `.claude/commands/ceo.md`, `engineer.md`, `product.md`, `marketing.md`, `uiux.md`, `tester-agent.md`:

1. Sostituisci i percorsi `agents/<ruolo>/` con `agents/<persona>/` secondo la mappa dello Step 1.
2. Inserisci come primo passo, prima della lettura del SOUL:

```markdown
0. **Se `agents/<persona>/SOUL.md` non esiste**, scrivilo prima di procedere: leggi `agents/<persona>/ROLE-BRIEF.md`, `agents/_authoring/SOUL-AUTHORING.md`, `shared-context/THESIS.md` e `shared-context/BRAND-GUIDE.md`, scrivi l'anima calata su questo progetto, salvala, e dichiara all'utente che l'hai appena forgiata. Poi continua dal passo 1.
```

- [ ] **Step 6: Aggiorna /startup**

In `.claude/commands/startup.md`:

1. Sostituisci la tabella statica dei sei ruoli con l'istruzione di leggere il team da `shared-context/TEAM.json` e costruire la tabella da lì (colonne: comando, nome, etichetta del ruolo).
2. Nella procedura, sostituisci "mappa il nome alla cartella corrispondente in `agents/`" con "risolvi il nome contro `TEAM.json`: accetta sia l'id sia il nome proprio, e usa il campo `folder`".
3. Aggiungi lo stesso passo 0 di authoring dello Step 5.

- [ ] **Step 7: Aggiorna /session e /wrap-up**

In `.claude/commands/session.md`, sostituisci l'elenco fisso delle sei sezioni agente con l'istruzione di generarle da `TEAM.json`, nell'ordine del manifest, con intestazione `## <Nome> — <Etichetta>`.

In `.claude/commands/wrap-up.md`, sostituisci la tabella dei log di ruolo con l'istruzione di leggere il proprio log dal campo `log` del manifest, e di saltare il passo se è `null`.

- [ ] **Step 8: Verifica manuale**

Apri una sessione e lancia `/startup stefano`. Verifica che carichi da `agents/stefano/` e che l'anima esistente non venga riscritta.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "refactor: cartelle agente per persona e slash command sul manifest"
```

---

## Task 13: Documentazione

**Files:**
- Modify: `CLAUDE.md`, `README.md`, `AGENTS.md`, `GEMINI.md`

- [ ] **Step 1: Aggiorna CLAUDE.md**

1. Nella sezione "Comandi", aggiungi `./agents/hire.sh`, `./tests/run.sh` e le due forme di `setup.sh` (interattiva e `--config`).
2. Nella sezione "Coordinamento via filesystem", aggiungi `TEAM.json` alla tabella dei file, con `setup.sh` e `hire.sh` come scrittori.
3. Sostituisci "Agenti validi ovunque (lowercase, validati dagli script)" con la spiegazione che gli id validi vengono dal manifest e che le `case` cablate non esistono più.
4. Aggiungi una sezione "Catalogo e manifest" che distingue `catalog/roles.json` (il possibile) da `shared-context/TEAM.json` (l'attuale), e nomina `agents/lib/team.sh` e `agents/lib/roster.sh` con la loro divisione di responsabilità.
5. Aggiorna la sezione "Il sistema multi-agente" con le cartelle per persona.
6. Aggiungi che i test si lanciano con `./tests/run.sh` e richiedono `git submodule update --init --recursive`.

- [ ] **Step 2: Aggiorna README.md**

1. Nella struttura del progetto, sostituisci le cartelle per ruolo con quelle per persona e aggiungi `catalog/`, `agents/lib/`, `tests/`.
2. Riscrivi "Quick Start" attorno al wizard: `./setup.sh` interattivo come percorso principale, `--config` come alternativa riproducibile.
3. Aggiungi una sezione "Aggiungere una persona" con `./agents/hire.sh`.
4. Aggiungi una sezione "Il catalogo" con le sette categorie e il conteggio delle figure, rimandando a `catalog/roles.json` per l'elenco.
5. Aggiorna la tabella degli agenti: non è più un elenco fisso ma il team di default proposto dal wizard.

- [ ] **Step 3: Aggiorna AGENTS.md e GEMINI.md**

In entrambi, sostituisci l'elenco fisso dei sei ruoli con l'istruzione di leggere `shared-context/TEAM.json` per sapere chi c'è, e `agents/<id>/IDENTITY.md` per i confini. Mantieni invariata la struttura dei passi (identifica il ruolo, carica il contesto, resta nel tuo dominio, aggiorna lo stato) e i prompt di avvio, resi generici sul manifest.

- [ ] **Step 4: Verifica che i riferimenti siano coerenti**

```bash
grep -rn "agents/ceo\|agents/engineer\|agents/product/\|agents/marketing/\|agents/uiux\|agents/tester" \
  --include="*.md" --include="*.sh" . | grep -v node_modules | grep -v "^./catalog/souls"
```

Expected: nessun risultato fuori da `catalog/` e dai file storici in `docs/`.

- [ ] **Step 5: Esegui l'intera suite un'ultima volta**

Run: `./tests/run.sh`
Expected: tutti PASS.

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md README.md AGENTS.md GEMINI.md
git commit -m "docs: catalogo, manifest, wizard e hire nella documentazione"
```
