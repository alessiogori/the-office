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
