#!/bin/zsh
# The Office — iTerm2 window launcher
# Crea una finestra iTerm2 separata per ogni agente con colore di sfondo distinto
# Uso: ./agents/iterm.sh <agente|all>
#
# Ogni finestra riceve un nome di sessione esplicito (es. "Stefano") tramite
# AppleScript + escape ANSI, in modo che msg.sh e ack.sh possano trovarla
# in modo affidabile con: name of aSession contains "<nome>"

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Colori di sfondo hex RGB per agente
typeset -A BG
BG=(
  [alessio]="2d0a0a"      # rosso scuro  — CEO
  [stefano]="0a0a2d"      # blu scuro    — Engineer
  [walter]="0a2d0a"       # verde scuro  — Product
  [veronica]="2d0a2d"     # viola scuro  — Marketing
  [alessandra]="0a2d2d"   # teal scuro   — UI/UX
  [marwen]="2d1a0a"       # arancione sc — Tester
)

# Nome breve usato anche da msg.sh / ack.sh per trovare la sessione
typeset -A NAME
NAME=(
  [alessio]="Alessio"
  [stefano]="Stefano"
  [walter]="Walter"
  [veronica]="Veronica"
  [alessandra]="Alessandra"
  [marwen]="Marwen"
)

typeset -A ROLE
ROLE=(
  [alessio]="CEO"
  [stefano]="Engineer"
  [walter]="Product"
  [veronica]="Marketing"
  [alessandra]="UI/UX"
  [marwen]="Tester"
)

open_window() {
  local agent=$1
  local hex="${BG[$agent]}"
  local name="${NAME[$agent]}"
  local role="${ROLE[$agent]}"

  # Converti hex → 0-65535 per AppleScript (ogni canale * 257)
  local r=$(( 16#${hex:0:2} * 257 ))
  local g=$(( 16#${hex:2:2} * 257 ))
  local b=$(( 16#${hex:4:2} * 257 ))

  osascript <<APPLESCRIPT
tell application "iTerm2"
  activate
  -- Crea sempre una nuova finestra dedicata (non un tab)
  set w to (create window with default profile)
  tell current session of current tab of w
    -- Imposta il nome sessione: usato da msg.sh/ack.sh per il lookup
    set name to "$name"
    set background color to {$r, $g, $b}
    -- printf iniziale: rinforza il titolo via escape ANSI (ESC]0;..BEL)
    -- in caso il nome AppleScript venisse sovrascritto dalla shell
    write text "printf '\\033]0;$name\\007'; cd '$PROJECT_DIR' && ./agents/launch.sh $agent"
  end tell
end tell
APPLESCRIPT

  echo "  ✓ $role — $name"
}

case "$1" in
  all)
    echo "Avvio tutti gli agenti..."
    for agent in alessio stefano walter veronica alessandra marwen; do
      open_window "$agent"
      sleep 0.4
    done
    echo "Pronti."
    ;;
  alessio|ceo)        open_window "alessio" ;;
  stefano|engineer)   open_window "stefano" ;;
  walter|product)     open_window "walter" ;;
  veronica|marketing) open_window "veronica" ;;
  alessandra|uiux)    open_window "alessandra" ;;
  marwen|tester)      open_window "marwen" ;;
  *)
    echo "Uso: ./agents/iterm.sh <agente|all>"
    echo ""
    echo "  alessio    — finestra rosso scuro    (CEO)"
    echo "  stefano    — finestra blu scuro      (Engineer)"
    echo "  walter     — finestra verde scuro    (Product)"
    echo "  veronica   — finestra viola scuro    (Marketing)"
    echo "  alessandra — finestra teal scuro     (UI/UX)"
    echo "  marwen     — finestra arancione sc.  (Tester)"
    echo "  all        — lancia tutti"
    ;;
esac
