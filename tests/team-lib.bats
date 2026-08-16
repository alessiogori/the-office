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

@test "team_validate confronta l'id letteralmente, non come regex" {
  use_manifest team-valid.json
  run team_validate "marwe."
  assert_failure
  run team_validate "s.efano"
  assert_failure
  run team_validate ".*"
  assert_failure
}
