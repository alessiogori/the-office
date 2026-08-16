#!/usr/bin/env bats
#
# Generazione end-to-end del wizard, via --config.
#
# La maggior parte di questi test si limita a ispezionare un progetto
# generato. Generarne uno nuovo per ciascuno costava circa 145 secondi:
# setup_file() ne produce due una volta sola — un export e una
# installazione diretta — e i test di sola lettura li riusano.
#
# I test che mutano lo stato, o che usano una configurazione diversa,
# generano il proprio: hanno il commento "genera il proprio".

load 'helpers/setup'

# ── Fixture condivise, generate una volta per file ───────────────────────────
setup_file() {
  export SHARED_FIXTURE_DIR="$(mktemp -d)"
  export SHARED_CONFIG="$SHARED_FIXTURE_DIR/config.json"
  export SHARED_TARGET="$SHARED_FIXTURE_DIR/progetto"
  export SHARED_EXPORTS="$SHARED_FIXTURE_DIR/exports"

  cat > "$SHARED_CONFIG" <<'JSON'
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

  local root="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
  "$root/setup.sh" --config "$SHARED_CONFIG" --target "$SHARED_TARGET" >/dev/null
  "$root/setup.sh" --config "$SHARED_CONFIG" --export-dir "$SHARED_EXPORTS" >/dev/null
}

teardown_file() {
  [ -n "$SHARED_FIXTURE_DIR" ] && rm -rf "$SHARED_FIXTURE_DIR"
}

setup() {
  setup_office_test
  # Per i test che generano il proprio progetto
  TARGET="$OFFICE_TEST_DIR/progetto"
  CONFIG="$OFFICE_TEST_DIR/config.json"
  cp "$SHARED_CONFIG" "$CONFIG"
  # Per i test di sola lettura
  T="$SHARED_TARGET"
  B="$SHARED_EXPORTS/flow"
}
teardown() { teardown_office_test; }

# ── Installazione diretta: struttura ─────────────────────────────────────────

@test "il wizard genera la struttura del progetto" {
  [ -d "$T/agents" ]
  [ -d "$T/shared-context" ]
  [ -f "$T/CLAUDE.md" ]
  [ -f "$T/AGENTS.md" ]
}

@test "il wizard crea una cartella per persona" {
  [ -d "$T/agents/giulia" ]
  [ -d "$T/agents/marco" ]
  [ -d "$T/agents/luca" ]
  [ -d "$T/agents/marwen" ]
}

@test "il wizard scrive TEAM.json con tutte le persone" {
  run python3 -c "import json,sys; print(' '.join(m['id'] for m in json.load(open(sys.argv[1]))['team']))" "$T/shared-context/TEAM.json"
  assert_output "giulia marco luca marwen"
}

@test "il primo membro è marcato coordinator" {
  run python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['team'][0]['coordinator'])" "$T/shared-context/TEAM.json"
  assert_output "True"
}

@test "i colori assegnati sono tutti diversi" {
  run python3 -c "
import json,sys
colors=[m['color'] for m in json.load(open(sys.argv[1]))['team']]
print('ok' if len(set(colors))==len(colors) else 'duplicati')
" "$T/shared-context/TEAM.json"
  assert_output "ok"
}

@test "il wizard copia gli script e le librerie" {
  [ -x "$T/agents/msg.sh" ]
  [ -x "$T/agents/setstatus.sh" ]
  [ -x "$T/agents/hire.sh" ]
  [ -f "$T/agents/lib/team.sh" ]
  [ -f "$T/agents/lib/roster.sh" ]
}

@test "il wizard copia il catalogo ma non tutte le anime" {
  [ -f "$T/catalog/roles.json" ]
  [ ! -d "$T/catalog/souls" ]
}

@test "il wizard copia le istruzioni di authoring" {
  [ -f "$T/agents/_authoring/SOUL-AUTHORING.md" ]
}

@test "un ruolo storico riceve la sua anima, uno nuovo no" {
  [ -f "$T/agents/marwen/SOUL.md" ]
  [ ! -f "$T/agents/marco/SOUL.md" ]
  [ -f "$T/agents/marco/ROLE-BRIEF.md" ]
}

@test "il wizard crea inbox e code per ogni persona" {
  [ -d "$T/shared-context/inbox/giulia" ]
  [ -f "$T/shared-context/queues/luca.json" ]
}

@test "il wizard genera i tre file di shared-context" {
  [ -f "$T/shared-context/THESIS.md" ]
  [ -f "$T/shared-context/ROADMAP.md" ]
  [ -f "$T/shared-context/BRAND-GUIDE.md" ]
  run grep -q "Laravel, Vue" "$T/shared-context/ROADMAP.md"
  assert_success
}

@test "CLAUDE.md generato elenca il team reale" {
  run grep -q "Giulia" "$T/CLAUDE.md"
  assert_success
  run grep -q "Luca" "$T/CLAUDE.md"
  assert_success
  run grep -q "Alessandra" "$T/CLAUDE.md"
  assert_failure
}

@test "in modalità --target non viene scritto INTEGRAZIONE.md" {
  [ ! -f "$T/INTEGRAZIONE.md" ]
}

@test "gli script generati funzionano sul team generato" {
  # genera il proprio: scrive AGENT-STATUS.json
  "$OFFICE_ROOT/setup.sh" --config "$CONFIG" --target "$TARGET" >/dev/null
  run env OFFICE_SHARED_DIR="$TARGET/shared-context" "$TARGET/agents/setstatus.sh" luca WORKING "API pagamenti"
  assert_success
  run env OFFICE_SHARED_DIR="$TARGET/shared-context" "$TARGET/agents/setstatus.sh" stefano IDLE
  assert_failure
}

# ── Modalità export ───────────────────────────────────────────────────────────

@test "senza --target il wizard esporta in exports/<slug>" {
  [ -d "$B" ]
  [ -f "$B/shared-context/TEAM.json" ]
}

@test "il bundle esportato è autonomo" {
  [ -x "$B/agents/setstatus.sh" ]
  [ -x "$B/agents/hire.sh" ]
  [ -f "$B/agents/lib/team.sh" ]
  [ -f "$B/agents/lib/roster.sh" ]
  [ -f "$B/catalog/roles.json" ]
  [ -d "$B/catalog/templates" ]
  [ -f "$B/agents/_authoring/SOUL-AUTHORING.md" ]
  [ -f "$B/CLAUDE.md" ]
}

@test "il bundle contiene le istruzioni di integrazione" {
  [ -f "$B/INTEGRAZIONE.md" ]
  run grep -q "flow" "$B/INTEGRAZIONE.md"
  assert_success
  run grep -qi "CLAUDE.md" "$B/INTEGRAZIONE.md"
  assert_success
}

@test "l'export elenca il team nelle istruzioni di integrazione" {
  run grep -q "Giulia" "$B/INTEGRAZIONE.md"
  assert_success
}

@test "gli script del bundle esportato funzionano" {
  # genera il proprio: scrive AGENT-STATUS.json nel bundle
  EXPORTS="$OFFICE_TEST_DIR/exports"
  "$OFFICE_ROOT/setup.sh" --config "$CONFIG" --export-dir "$EXPORTS" >/dev/null
  run env OFFICE_SHARED_DIR="$EXPORTS/flow/shared-context" "$EXPORTS/flow/agents/setstatus.sh" marco WORKING "API"
  assert_success
}

@test "lo slug dell'export tiene i trattini del nome progetto" {
  # genera il proprio: nome progetto diverso
  EXPORTS="$OFFICE_TEST_DIR/exports"
  python3 - "$CONFIG" <<'PY'
import json, sys
c = json.load(open(sys.argv[1]))
c["project"]["name"] = "Acme Shop 2026"
json.dump(c, open(sys.argv[1], "w"))
PY
  "$OFFICE_ROOT/setup.sh" --config "$CONFIG" --export-dir "$EXPORTS" >/dev/null
  [ -d "$EXPORTS/acme-shop-2026" ]
}

@test "un export già esistente e non vuoto viene rifiutato" {
  EXPORTS="$OFFICE_TEST_DIR/exports"
  mkdir -p "$EXPORTS/flow"
  echo "roba mia" > "$EXPORTS/flow/file.txt"
  run "$OFFICE_ROOT/setup.sh" --config "$CONFIG" --export-dir "$EXPORTS"
  [ "$status" -eq 2 ]
  assert_output --partial "flow"
  run cat "$EXPORTS/flow/file.txt"
  assert_output "roba mia"
}

# ── Protezione della directory di destinazione ────────────────────────────────

@test "--target su directory non vuota viene rifiutata senza --force" {
  mkdir -p "$TARGET"
  echo "progetto esistente" > "$TARGET/CLAUDE.md"
  run "$OFFICE_ROOT/setup.sh" --config "$CONFIG" --target "$TARGET"
  [ "$status" -eq 2 ]
  assert_output --partial "force"
  run cat "$TARGET/CLAUDE.md"
  assert_output "progetto esistente"
}

@test "--force accetta una directory non vuota" {
  mkdir -p "$TARGET"
  echo "progetto esistente" > "$TARGET/CLAUDE.md"
  run "$OFFICE_ROOT/setup.sh" --config "$CONFIG" --target "$TARGET" --force
  assert_success
  run grep -q "Giulia" "$TARGET/CLAUDE.md"
  assert_success
}

@test "--target su directory vuota non richiede --force" {
  mkdir -p "$TARGET"
  run "$OFFICE_ROOT/setup.sh" --config "$CONFIG" --target "$TARGET"
  assert_success
}

@test "--save-config esporta la configurazione usata" {
  OUT="$OFFICE_TEST_DIR/saved.json"
  "$OFFICE_ROOT/setup.sh" --config "$CONFIG" --target "$TARGET" --save-config "$OUT" >/dev/null
  [ -f "$OUT" ]
  run python3 -c "import json,sys; print(len(json.load(open(sys.argv[1]))['team']))" "$OUT"
  assert_output "4"
}

# ── Validazione: nessuna di queste genera niente ─────────────────────────────

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
