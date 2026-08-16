#!/usr/bin/env bats

load 'helpers/setup'

setup() {
  setup_office_test
  source "$OFFICE_ROOT/agents/lib/roster.sh"
  DEST="$OFFICE_TEST_DIR/agents"
  mkdir -p "$DEST"
  EMPTY_TEAM="$OFFICE_SHARED_DIR/TEAM.json"
  echo '{"version":1,"team":[]}' > "$EMPTY_TEAM"
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
  roster_generate_person backend "Marco" marco "$DEST" "$EMPTY_TEAM"
  [ -f "$DEST/marco/IDENTITY.md" ]
  [ -f "$DEST/marco/HEARTBEAT.md" ]
  [ -f "$DEST/marco/ROLE-BRIEF.md" ]
  [ -f "$DEST/marco/BUILD-LOG.md" ]
}

@test "roster_generate_person non crea SOUL.md per un ruolo senza anima nel catalogo" {
  roster_generate_person backend "Marco" marco "$DEST" "$EMPTY_TEAM"
  [ ! -f "$DEST/marco/SOUL.md" ]
}

@test "roster_generate_person copia SOUL.md per un ruolo storico" {
  roster_generate_person tester "Marwen" marwen "$DEST" "$EMPTY_TEAM"
  [ -f "$DEST/marwen/SOUL.md" ]
  run grep -q "Marwen" "$DEST/marwen/SOUL.md"
  assert_success
  run grep -q "__AGENT_NAME__" "$DEST/marwen/SOUL.md"
  assert_failure
}

@test "roster_generate_person sostituisce anche l'id nell'anima" {
  roster_generate_person tester "Chiara" chiara "$DEST" "$EMPTY_TEAM"
  run grep -q "__AGENT_ID__" "$DEST/chiara/SOUL.md"
  assert_failure
  run grep -q "msg.sh chiara" "$DEST/chiara/SOUL.md"
  assert_success
}

@test "roster_generate_person non crea un log per un ruolo senza log" {
  roster_generate_person ceo "Alessio" alessio "$DEST" "$EMPTY_TEAM"
  [ -f "$DEST/alessio/IDENTITY.md" ]
  run bash -c "ls '$DEST/alessio/' | grep -i 'log'"
  assert_failure
}

@test "IDENTITY.md contiene i confini e l'attrito del ruolo" {
  roster_generate_person backend "Marco" marco "$DEST" "$EMPTY_TEAM"
  run grep -q "Marco" "$DEST/marco/IDENTITY.md"
  assert_success
  run grep -qi "non può" "$DEST/marco/IDENTITY.md"
  assert_success
  run grep -qi "attrito" "$DEST/marco/IDENTITY.md"
  assert_success
}

@test "IDENTITY.md compila i comandi msg.sh con l'id della persona" {
  roster_generate_person backend "Marco" marco "$DEST" "$EMPTY_TEAM"
  run grep -q "msg.sh marco" "$DEST/marco/IDENTITY.md"
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

@test "roster_slugify mantiene i trattini a differenza di roster_id_from_name" {
  run roster_slugify "acme-shop"
  assert_output "acme-shop"
  run roster_id_from_name "acme-shop"
  assert_output "acmeshop"
}

@test "roster_slugify normalizza spazi e accenti" {
  run roster_slugify "Progetto Città 2026"
  assert_output "progetto-citta-2026"
}

@test "roster_slugify collassa separatori ripetuti e ripulisce i bordi" {
  run roster_slugify "  --Acme__Shop--  "
  assert_output "acme-shop"
}
