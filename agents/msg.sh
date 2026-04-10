#!/bin/bash
# msg.sh — Invia un messaggio direttamente nel prompt Claude Code di un altro agente
# Uso: ./agents/msg.sh <destinatario> "<messaggio>"
# Esempio: ./agents/msg.sh walter "Ho finito il modulo pagamenti. Rivedi docs/payments.md."

RECIPIENT=$(echo "$1" | tr '[:upper:]' '[:lower:]')
MESSAGE="$2"

if [[ -z "$RECIPIENT" || -z "$MESSAGE" ]]; then
  echo "Uso: ./agents/msg.sh <destinatario> \"<messaggio>\""
  echo "Destinatari: alessio, stefano, walter, veronica, alessandra, marwen"
  exit 1
fi

case "$RECIPIENT" in
  alessio)    WINDOW_NAME="Alessio" ;;
  stefano)    WINDOW_NAME="Stefano" ;;
  walter)     WINDOW_NAME="Walter" ;;
  veronica)   WINDOW_NAME="Veronica" ;;
  alessandra) WINDOW_NAME="Alessandra" ;;
  marwen)     WINDOW_NAME="Marwen" ;;
  *)
    echo "Destinatario '$RECIPIENT' non riconosciuto."
    echo "Destinatari validi: alessio, stefano, walter, veronica, alessandra, marwen"
    exit 1
    ;;
esac

osascript << EOF
tell application "iTerm2"
  set delivered to false
  repeat with aWindow in windows
    repeat with aTab in tabs of aWindow
      repeat with aSession in sessions of aTab
        if profile name of aSession contains "$WINDOW_NAME" then
          tell aSession
            write text "MESSAGGIO IN ARRIVO - metti in coda: $MESSAGE"
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
  end if
end tell
EOF

echo "Messaggio inviato a $WINDOW_NAME."
