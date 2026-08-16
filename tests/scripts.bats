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
