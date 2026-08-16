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

@test "hire normalizza gli accenti nell'id" {
  "$OFFICE_ROOT/agents/hire.sh" security "Niccolò"
  [ -d "$OFFICE_AGENTS_DIR/niccolo" ]
  run python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['team'][-1]['name'])" "$OFFICE_SHARED_DIR/TEAM.json"
  assert_output "Niccolò"
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

@test "se un passo fallisce la persona non resta nel manifest" {
  # inbox/ occupata da un file: mkdir del passo 3 fallisce
  rm -rf "$OFFICE_SHARED_DIR/inbox"
  touch "$OFFICE_SHARED_DIR/inbox"
  run "$OFFICE_ROOT/agents/hire.sh" backend "Luca"
  assert_failure
  run python3 -c "import json,sys; print(' '.join(m['id'] for m in json.load(open(sys.argv[1]))['team']))" "$OFFICE_SHARED_DIR/TEAM.json"
  refute_output --partial "luca"
  [ ! -d "$OFFICE_AGENTS_DIR/luca" ]
}
