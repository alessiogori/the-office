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

@test "il wizard crea inbox e code per ogni persona" {
  "$OFFICE_ROOT/setup.sh" --config "$CONFIG" --target "$TARGET"
  [ -d "$TARGET/shared-context/inbox/giulia" ]
  [ -f "$TARGET/shared-context/queues/luca.json" ]
}

@test "il wizard genera i tre file di shared-context" {
  "$OFFICE_ROOT/setup.sh" --config "$CONFIG" --target "$TARGET"
  [ -f "$TARGET/shared-context/THESIS.md" ]
  [ -f "$TARGET/shared-context/ROADMAP.md" ]
  [ -f "$TARGET/shared-context/BRAND-GUIDE.md" ]
  run grep -q "Laravel, Vue" "$TARGET/shared-context/ROADMAP.md"
  assert_success
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

@test "--save-config esporta la configurazione usata" {
  OUT="$OFFICE_TEST_DIR/saved.json"
  "$OFFICE_ROOT/setup.sh" --config "$CONFIG" --target "$TARGET" --save-config "$OUT"
  [ -f "$OUT" ]
  run python3 -c "import json,sys; print(len(json.load(open(sys.argv[1]))['team']))" "$OUT"
  assert_output "4"
}
