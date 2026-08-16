#!/usr/bin/env bats
#
# Il percorso interattivo del wizard, pilotato via pseudo-terminale.
# Questi test coprono ciò che la modalità --config non può coprire: le
# schermate gum vere, nell'ordine vero, con l'input di un utente.
#
# Richiedono gum, expect e un terminale vero. Sotto bats lo stdin è
# /dev/null, e in quelle condizioni expect non riesce a stabilire lo
# pseudo-terminale: resta appeso. Per questo i test girano solo con
# l'opt-in esplicito OFFICE_TUI_TESTS=1 da un terminale interattivo:
#
#   OFFICE_TUI_TESTS=1 ./tests/run.sh tests/tui-interactive.bats
#
# Altrove si saltano. Un test che si appende è peggio di un test assente.

load 'helpers/setup'

setup() {
  setup_office_test
  [ -n "${OFFICE_TUI_TESTS:-}" ] || skip "serve OFFICE_TUI_TESTS=1 e un terminale interattivo"
  command -v gum >/dev/null 2>&1 || skip "gum non installato"
  command -v expect >/dev/null 2>&1 || skip "expect non installato"
  [ -t 0 ] || skip "stdin non è un terminale: expect non può creare lo pty"
  DRIVER="$OFFICE_ROOT/tests/helpers/drive-wizard.exp"
  EXPORTS="$OFFICE_TEST_DIR/exports"
  mkdir -p "$EXPORTS"
}
teardown() { teardown_office_test; }

@test "il wizard interattivo produce un bundle completo" {
  cd "$OFFICE_ROOT"
  run "$DRIVER" "$EXPORTS" "tui-demo" "2" "backend" "Giulia" "Marco"
  assert_success
  assert_output --partial "WIZARD-OK"
  [ -d "$EXPORTS/tui-demo" ]
  [ -f "$EXPORTS/tui-demo/shared-context/TEAM.json" ]
  [ -f "$EXPORTS/tui-demo/INTEGRAZIONE.md" ]
}

@test "il wizard interattivo rispetta i ruoli e i nomi scelti" {
  cd "$OFFICE_ROOT"
  "$DRIVER" "$EXPORTS" "tui-demo" "2" "backend" "Giulia" "Marco"
  run python3 -c "
import json,sys
t=json.load(open(sys.argv[1]))['team']
print(' '.join(f\"{m['id']}:{m['role']}\" for m in t))
" "$EXPORTS/tui-demo/shared-context/TEAM.json"
  assert_output "giulia:ceo marco:backend"
}

@test "la prima persona scelta dal wizard è un coordinatore" {
  cd "$OFFICE_ROOT"
  "$DRIVER" "$EXPORTS" "tui-demo" "2" "backend" "Giulia" "Marco"
  run python3 -c "
import json,sys
print(json.load(open(sys.argv[1]))['team'][0]['coordinator'])
" "$EXPORTS/tui-demo/shared-context/TEAM.json"
  assert_output "True"
}

@test "lo slug del progetto scelto interattivamente conserva i trattini" {
  cd "$OFFICE_ROOT"
  "$DRIVER" "$EXPORTS" "acme-shop" "2" "tester" "Giulia" "Davide"
  [ -d "$EXPORTS/acme-shop" ]
}

@test "il bundle prodotto dal wizard interattivo è usabile" {
  cd "$OFFICE_ROOT"
  "$DRIVER" "$EXPORTS" "tui-demo" "2" "backend" "Giulia" "Marco"
  run env OFFICE_SHARED_DIR="$EXPORTS/tui-demo/shared-context" \
    "$EXPORTS/tui-demo/agents/setstatus.sh" marco WORKING "Prima task"
  assert_success
}
