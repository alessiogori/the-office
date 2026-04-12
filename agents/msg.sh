#!/bin/bash
# msg.sh — Invia un messaggio strutturato nel prompt Claude Code di un altro agente
# Uso:     ./agents/msg.sh <mittente> <destinatario> "<messaggio>"
# Esempio: ./agents/msg.sh stefano walter "Ho finito il modulo pagamenti. Rivedi docs/payments.md."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/../shared-context/MSG-LOG.jsonl"

FROM=$(echo "$1" | tr '[:upper:]' '[:lower:]')
RECIPIENT=$(echo "$2" | tr '[:upper:]' '[:lower:]')
MESSAGE="$3"

if [[ -z "$FROM" || -z "$RECIPIENT" || -z "$MESSAGE" ]]; then
  echo "Uso: ./agents/msg.sh <mittente> <destinatario> \"<messaggio>\""
  echo "Agenti: alessio, stefano, walter, veronica, alessandra, marwen"
  exit 1
fi

# ── Risolvi nomi visualizzati ─────────────────────────────────────────────────
resolve_name() {
  case "$1" in
    alessio)    echo "Alessio" ;;
    stefano)    echo "Stefano" ;;
    walter)     echo "Walter" ;;
    veronica)   echo "Veronica" ;;
    alessandra) echo "Alessandra" ;;
    marwen)     echo "Marwen" ;;
    *)          echo "" ;;
  esac
}

FROM_NAME=$(resolve_name "$FROM")
WINDOW_NAME=$(resolve_name "$RECIPIENT")

if [[ -z "$FROM_NAME" ]]; then
  echo "Mittente '$FROM' non riconosciuto."
  echo "Agenti validi: alessio, stefano, walter, veronica, alessandra, marwen"
  exit 1
fi

if [[ -z "$WINDOW_NAME" ]]; then
  echo "Destinatario '$RECIPIENT' non riconosciuto."
  echo "Agenti validi: alessio, stefano, walter, veronica, alessandra, marwen"
  exit 1
fi

# ── Genera timestamp e ID univoco ─────────────────────────────────────────────
TIMESTAMP=$(date "+%Y-%m-%dT%H:%M:%S")
MSG_ID="msg-$(date +%Y%m%d-%H%M%S)-${FROM:0:3}${RECIPIENT:0:3}"

# ── Scrivi evento SENT nel log JSONL ──────────────────────────────────────────
# Escape del messaggio per JSON (backslash, doppi apici, newline)
MSG_ESCAPED=$(printf '%s' "$MESSAGE" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/g' | tr -d '\n' | sed 's/\\n$//')

printf '{"id":"%s","type":"SENT","ts":"%s","from":"%s","to":"%s","msg":"%s"}\n' \
  "$MSG_ID" "$TIMESTAMP" "$FROM_NAME" "$WINDOW_NAME" "$MSG_ESCAPED" >> "$LOG_FILE"

# ── Componi il messaggio strutturato per iTerm2 ───────────────────────────────
read -r -d '' FORMATTED_MSG << MSG || true
--- MESSAGGIO IN ARRIVO ---
Da:        $FROM_NAME
A:         $WINDOW_NAME
Timestamp: $TIMESTAMP
ID:        $MSG_ID

$MESSAGE

Per rispondere:          ./agents/msg.sh $FROM $RECIPIENT "<tua risposta>"
Per confermare ricezione: ./agents/ack.sh $MSG_ID $RECIPIENT
---------------------------
MSG

# ── Invia via iTerm2 AppleScript ──────────────────────────────────────────────
RESULT=$(osascript << EOF
tell application "iTerm2"
  set delivered to false
  repeat with aWindow in windows
    repeat with aTab in tabs of aWindow
      repeat with aSession in sessions of aTab
        if profile name of aSession contains "$WINDOW_NAME" then
          tell aSession
            write text "$FORMATTED_MSG"
          end tell
          set delivered to true
          exit repeat
        end if
      end repeat
      if delivered then exit repeat
    end repeat
    if delivered then exit repeat
  end repeat
  if not delivered then
    display notification "Finestra '$WINDOW_NAME' non trovata in iTerm2." with title "msg.sh — errore"
    return "NOT_FOUND"
  end if
  return "OK"
end tell
EOF
)

if [[ "$RESULT" == "NOT_FOUND" ]]; then
  echo "Errore: finestra '$WINDOW_NAME' non trovata in iTerm2."
  echo "Il messaggio è stato loggato in MSG-LOG.jsonl con stato SENT."
  echo "ID messaggio: $MSG_ID"
  exit 1
fi

echo "Messaggio inviato a $WINDOW_NAME."
echo "ID:  $MSG_ID"
echo "Log: shared-context/MSG-LOG.jsonl"
