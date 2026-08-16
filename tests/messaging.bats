#!/usr/bin/env bats

load 'helpers/setup'

setup() {
  setup_office_test
  use_manifest team-valid.json
  export OFFICE_NO_ITERM=1
}
teardown() { teardown_office_test; }

# Estrae l'id del primo evento SENT dal log.
first_sent_id() {
  python3 - "$OFFICE_SHARED_DIR/MSG-LOG.jsonl" <<'PY'
import json, sys
for line in open(sys.argv[1]):
    e = json.loads(line)
    if e.get("type") == "SENT":
        print(e["id"])
        break
PY
}

@test "msg accetta mittente e destinatario del manifest" {
  run "$OFFICE_ROOT/agents/msg.sh" stefano marwen "Fix pronto"
  assert_success
}

@test "msg scrive un evento SENT nel log" {
  "$OFFICE_ROOT/agents/msg.sh" stefano marwen "Fix pronto"
  run grep -c '"type": *"SENT"' "$OFFICE_SHARED_DIR/MSG-LOG.jsonl"
  assert_output "1"
}

@test "msg deposita il messaggio nell'inbox del destinatario" {
  "$OFFICE_ROOT/agents/msg.sh" stefano marwen "Fix pronto"
  run bash -c "ls '$OFFICE_SHARED_DIR/inbox/marwen/' | wc -l | tr -d ' '"
  assert_output "1"
}

@test "msg usa il nome visualizzato dal manifest" {
  "$OFFICE_ROOT/agents/msg.sh" stefano marwen "Fix pronto"
  run grep -q '"from": *"Stefano"' "$OFFICE_SHARED_DIR/MSG-LOG.jsonl"
  assert_success
}

@test "msg rifiuta un mittente fuori dal manifest" {
  run "$OFFICE_ROOT/agents/msg.sh" pippo marwen "ciao"
  assert_failure
  assert_output --partial "pippo"
}

@test "msg rifiuta un destinatario fuori dal manifest" {
  run "$OFFICE_ROOT/agents/msg.sh" stefano pippo "ciao"
  assert_failure
  assert_output --partial "pippo"
}

@test "msg rifiuta mittente e destinatario coincidenti" {
  run "$OFFICE_ROOT/agents/msg.sh" stefano stefano "ciao"
  assert_failure
}

@test "msg funziona con un team a ruoli duplicati" {
  use_manifest team-duplicates.json
  run "$OFFICE_ROOT/agents/msg.sh" marco luca "Ti passo lo schema"
  assert_success
  run grep -q '"to": *"Luca"' "$OFFICE_SHARED_DIR/MSG-LOG.jsonl"
  assert_success
}

@test "ack registra un evento ACK per un messaggio esistente" {
  "$OFFICE_ROOT/agents/msg.sh" stefano marwen "Fix pronto"
  MSG_ID=$(first_sent_id)
  run "$OFFICE_ROOT/agents/ack.sh" "$MSG_ID" marwen
  assert_success
  run grep -c '"type": *"ACK"' "$OFFICE_SHARED_DIR/MSG-LOG.jsonl"
  assert_output "1"
}

@test "ack rifiuta un agente fuori dal manifest" {
  run "$OFFICE_ROOT/agents/ack.sh" msg-inesistente pippo
  assert_failure
  assert_output --partial "pippo"
}

@test "il log resta append-only: SENT sopravvive all'ACK" {
  "$OFFICE_ROOT/agents/msg.sh" stefano marwen "Fix pronto"
  MSG_ID=$(first_sent_id)
  "$OFFICE_ROOT/agents/ack.sh" "$MSG_ID" marwen
  run grep -c '"type": *"SENT"' "$OFFICE_SHARED_DIR/MSG-LOG.jsonl"
  assert_output "1"
}

@test "due messaggi nello stesso secondo non collidono" {
  "$OFFICE_ROOT/agents/msg.sh" stefano marwen "primo"
  "$OFFICE_ROOT/agents/msg.sh" stefano marwen "secondo"
  run bash -c "ls '$OFFICE_SHARED_DIR/inbox/marwen/' | wc -l | tr -d ' '"
  assert_output "2"
  run bash -c "python3 -c \"
import json,sys
ids=[json.loads(l)['id'] for l in open('$OFFICE_SHARED_DIR/MSG-LOG.jsonl') if json.loads(l)['type']=='SENT']
print('unici' if len(set(ids))==len(ids) else 'collisi')\""
  assert_output "unici"
}

@test "msg rifiuta un destinatario che assomiglia a una regex" {
  run "$OFFICE_ROOT/agents/msg.sh" stefano "marwe." "test"
  assert_failure
  [ ! -d "$OFFICE_SHARED_DIR/inbox/marwe." ]
}

@test "ack rifiuta chi non è il destinatario del messaggio" {
  "$OFFICE_ROOT/agents/msg.sh" stefano marwen "Fix pronto"
  MSG_ID=$(first_sent_id)
  run "$OFFICE_ROOT/agents/ack.sh" "$MSG_ID" alessio
  assert_failure
  assert_output --partial "Marwen"
  run grep -c '"type": *"ACK"' "$OFFICE_SHARED_DIR/MSG-LOG.jsonl"
  assert_output "0"
}

@test "dopo un ack rifiutato il destinatario può ancora confermare" {
  "$OFFICE_ROOT/agents/msg.sh" stefano marwen "Fix pronto"
  MSG_ID=$(first_sent_id)
  "$OFFICE_ROOT/agents/ack.sh" "$MSG_ID" alessio || true
  run "$OFFICE_ROOT/agents/ack.sh" "$MSG_ID" marwen
  assert_success
}
