#!/bin/bash
# ack.sh — Conferma la ricezione di un messaggio inter-agente
# Uso:     ./agents/ack.sh <msg-id> <agente-corrente>
# Esempio: ./agents/ack.sh msg-20260412-153042-stewa marwen

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/team.sh"

SHARED_DIR="${OFFICE_SHARED_DIR:-$SCRIPT_DIR/../shared-context}"
LOG_FILE="$SHARED_DIR/MSG-LOG.jsonl"
INBOX_DIR="$SHARED_DIR/inbox"

MSG_ID="$1"
ACK_BY_RAW=$(echo "${2:-}" | tr '[:upper:]' '[:lower:]')

if [[ -z "$MSG_ID" || -z "$ACK_BY_RAW" ]]; then
  echo "Uso: ./agents/ack.sh <msg-id> <agente-corrente>" >&2
  echo "Agenti: $(team_ids | tr '\n' ' ')" >&2
  exit 1
fi

team_validate "$ACK_BY_RAW" || exit 1

if [[ ! -f "$LOG_FILE" ]]; then
  echo "Errore: $LOG_FILE non trovato." >&2
  exit 1
fi

# ── Verifica che il msg-id esista nel log ─────────────────────────────────────
SENT_LINE=$(grep "\"id\":\"$MSG_ID\"" "$LOG_FILE" | grep "\"type\":\"SENT\"" | tail -1)

if [[ -z "$SENT_LINE" ]]; then
  echo "Errore: ID '$MSG_ID' non trovato in MSG-LOG.jsonl (o non è un evento SENT)." >&2
  exit 1
fi

# ── Verifica che non sia già stato ACK'd ──────────────────────────────────────
EXISTING_ACK=$(grep "\"id\":\"$MSG_ID\"" "$LOG_FILE" | grep "\"type\":\"ACK\"" | tail -1)
if [[ -n "$EXISTING_ACK" ]]; then
  echo "Attenzione: il messaggio '$MSG_ID' è già stato confermato."
  echo "$EXISTING_ACK"
  exit 0
fi

# ── Nome visualizzato dell'agente che fa ACK, dal manifest ───────────────────
ACK_BY_NAME=$(team_get "$ACK_BY_RAW" name)

# ── Solo il destinatario può confermare ──────────────────────────────────────
# Un ACK da parte di un terzo lascerebbe il file nell'inbox del vero
# destinatario e gli impedirebbe di confermare a sua volta.
EXPECTED_TO=$(echo "$SENT_LINE" | grep -o '"to":"[^"]*"' | cut -d'"' -f4)
if [ -n "$EXPECTED_TO" ] && [ "$EXPECTED_TO" != "$ACK_BY_NAME" ]; then
  echo "Errore: '$MSG_ID' è indirizzato a $EXPECTED_TO, non a $ACK_BY_NAME." >&2
  echo "Solo il destinatario può confermare un messaggio." >&2
  exit 1
fi

# ── Estrai mittente originale dal log (per notifica di ritorno) ───────────────
# Il JSON ha il campo "from", es: "from":"Stefano"
FROM_NAME=$(echo "$SENT_LINE" | grep -o '"from":"[^"]*"' | cut -d'"' -f4)
TO_NAME=$(echo "$SENT_LINE"   | grep -o '"to":"[^"]*"'   | cut -d'"' -f4)

# ── Scrivi evento ACK nel log JSONL ───────────────────────────────────────────
ACK_TIMESTAMP=$(date "+%Y-%m-%dT%H:%M:%S")

printf '{"id":"%s","type":"ACK","ts":"%s","ack_by":"%s","original_from":"%s","original_to":"%s"}\n' \
  "$MSG_ID" "$ACK_TIMESTAMP" "$ACK_BY_NAME" "$FROM_NAME" "$TO_NAME" >> "$LOG_FILE"

echo "ACK registrato."
echo "  Messaggio: $MSG_ID"
echo "  Inviato da: $FROM_NAME  →  a: $TO_NAME"
echo "  Confermato da: $ACK_BY_NAME  alle $ACK_TIMESTAMP"
echo "  Log: shared-context/MSG-LOG.jsonl"

# ── Elimina il file inbox (messaggio processato) ──────────────────────────────
INBOX_FILE="$INBOX_DIR/$ACK_BY_RAW/$MSG_ID.md"
if [[ -f "$INBOX_FILE" ]]; then
  rm "$INBOX_FILE"
  echo "  Inbox: shared-context/inbox/$ACK_BY_RAW/$MSG_ID.md rimosso."
fi

# ── Notifica il mittente originale in iTerm2 ─────────────────────────────────
if [[ -n "$FROM_NAME" && -z "${OFFICE_NO_ITERM:-}" ]] && command -v osascript >/dev/null 2>&1; then
  NOTIFY_RESULT=$(osascript << EOF
tell application "iTerm2"
  set notified to false
  set ackText to "--- ACK RICEVUTO --- ID: $MSG_ID | Confermato da: $ACK_BY_NAME | $ACK_TIMESTAMP ---"
  repeat with aWindow in windows
    repeat with aTab in tabs of aWindow
      repeat with aSession in sessions of aTab
        set sessionMatched to false
        try
          if name of aSession contains "$FROM_NAME" then set sessionMatched to true
        end try
        if not sessionMatched then
          try
            if profile name of aSession contains "$FROM_NAME" then set sessionMatched to true
          end try
        end if
        if not sessionMatched then
          try
            if name of aWindow contains "$FROM_NAME" then set sessionMatched to true
          end try
        end if
        if sessionMatched then
          tell aSession
            write text ackText newline NO
            delay 0.15
            write text "" & return newline NO
          end tell
          set notified to true
          exit repeat
        end if
      end repeat
      if notified then exit repeat
    end repeat
    if notified then exit repeat
  end repeat
  if not notified then
    return "NOT_FOUND"
  end if
  return "OK"
end tell
EOF
)

  if [[ "$NOTIFY_RESULT" == "NOT_FOUND" ]]; then
    echo "Avviso: finestra '$FROM_NAME' non trovata in iTerm2 — ACK non consegnato in real-time."
    echo "Suggerimento: apri la finestra con  ./agents/iterm.sh $(echo "$FROM_NAME" | tr '[:upper:]' '[:lower:]')"
  fi
fi
