#!/bin/bash
# ack.sh — Conferma la ricezione di un messaggio inter-agente
# Uso:     ./agents/ack.sh <msg-id> <agente-corrente>
# Esempio: ./agents/ack.sh msg-20260412-153042-stewa marwen

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/../shared-context/MSG-LOG.jsonl"

MSG_ID="$1"
ACK_BY_RAW=$(echo "${2:-}" | tr '[:upper:]' '[:lower:]')

if [[ -z "$MSG_ID" || -z "$ACK_BY_RAW" ]]; then
  echo "Uso: ./agents/ack.sh <msg-id> <agente-corrente>"
  echo "Esempio: ./agents/ack.sh msg-20260412-153042-stewa marwen"
  exit 1
fi

if [[ ! -f "$LOG_FILE" ]]; then
  echo "Errore: MSG-LOG.jsonl non trovato in shared-context/."
  exit 1
fi

# ── Verifica che il msg-id esista nel log ─────────────────────────────────────
SENT_LINE=$(grep "\"id\":\"$MSG_ID\"" "$LOG_FILE" | grep "\"type\":\"SENT\"" | tail -1)

if [[ -z "$SENT_LINE" ]]; then
  echo "Errore: ID '$MSG_ID' non trovato in MSG-LOG.jsonl (o non è un evento SENT)."
  exit 1
fi

# ── Verifica che non sia già stato ACK'd ──────────────────────────────────────
EXISTING_ACK=$(grep "\"id\":\"$MSG_ID\"" "$LOG_FILE" | grep "\"type\":\"ACK\"" | tail -1)
if [[ -n "$EXISTING_ACK" ]]; then
  echo "Attenzione: il messaggio '$MSG_ID' è già stato confermato."
  echo "$EXISTING_ACK"
  exit 0
fi

# ── Risolvi nome visualizzato dell'agente che fa ACK ─────────────────────────
resolve_name() {
  case "$1" in
    alessio)    echo "Alessio" ;;
    stefano)    echo "Stefano" ;;
    walter)     echo "Walter" ;;
    veronica)   echo "Veronica" ;;
    alessandra) echo "Alessandra" ;;
    marwen)     echo "Marwen" ;;
    *)          echo "$1" ;;
  esac
}

ACK_BY_NAME=$(resolve_name "$ACK_BY_RAW")

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

# ── Notifica il mittente originale in iTerm2 ─────────────────────────────────
if [[ -n "$FROM_NAME" ]]; then
  osascript << EOF
tell application "iTerm2"
  set notified to false
  repeat with aWindow in windows
    repeat with aTab in tabs of aWindow
      repeat with aSession in sessions of aTab
        if profile name of aSession contains "$FROM_NAME" then
          tell aSession
            write text "--- ACK RICEVUTO --- ID: $MSG_ID | Confermato da: $ACK_BY_NAME | $ACK_TIMESTAMP ---"
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
    display notification "ACK per $MSG_ID da $ACK_BY_NAME (finestra $FROM_NAME non attiva)." with title "ack.sh"
  end if
end tell
EOF
fi
