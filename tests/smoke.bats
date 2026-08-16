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
