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

@test "tui_gum_available riporta assenza quando OFFICE_ASSUME_NO_GUM è impostata" {
  run bash -c "source '$OFFICE_ROOT/agents/lib/tui.sh'; OFFICE_ASSUME_NO_GUM=1 tui_gum_available && echo si || echo no"
  assert_output "no"
}

@test "il rilevamento del gestore di pacchetti restituisce un comando noto" {
  run tui_install_hint
  assert_success
  case "$output" in
    *brew*|*apt*|*"go install"*|*"github.com/charmbracelet/gum"*) ;;
    *) false ;;
  esac
}

@test "tui_require_gum rifiutato esce con codice 2 e suggerisce --config" {
  run bash -c "printf 'n\n' | OFFICE_ASSUME_NO_GUM=1 bash -c \"source '$OFFICE_ROOT/agents/lib/tui.sh'; tui_require_gum\""
  [ "$status" -eq 2 ]
  assert_output --partial "--config"
}

@test "setup.sh senza gum e senza --config non scrive nulla" {
  TARGET="$OFFICE_TEST_DIR/mai-creato"
  run bash -c "printf 'n\n' | OFFICE_ASSUME_NO_GUM=1 '$OFFICE_ROOT/setup.sh' --target '$TARGET'"
  [ "$status" -eq 2 ]
  [ ! -d "$TARGET" ]
}
