#!/bin/zsh
# The Office — iTerm2 dynamic session launcher
# Crea tab iTerm2 per ogni agente con colore di sfondo distinto
# Uso: ./agents/iterm.sh <agente|all>

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

typeset -A LABEL
LABEL=(
  [alessio]="CEO — Alessio"
  [stefano]="Engineer — Stefano"
  [walter]="Product — Walter"
  [veronica]="Marketing — Veronica"
  [alessandra]="UI/UX — Alessandra"
  [marwen]="Tester — Marwen"
)

open_tab() {
  local agent=$1
  local hex="${BG[$agent]}"

  # Converti hex → 0-65535 per AppleScript (ogni canale * 257)
  local r=$(( 16#${hex:0:2} * 257 ))
  local g=$(( 16#${hex:2:2} * 257 ))
  local b=$(( 16#${hex:4:2} * 257 ))

  osascript <<APPLESCRIPT
tell application "iTerm2"
  activate
  if (count of windows) = 0 then
    set w to (create window with default profile)
  else
    set w to current window
  end if
  tell w
    set t to (create tab with default profile)
    tell t
      tell current session
        set background color to {$r, $g, $b}
        write text "cd '$PROJECT_DIR' && ./agents/launch.sh $agent"
      end tell
    end tell
  end tell
end tell
APPLESCRIPT

  echo "  ✓ ${LABEL[$agent]}"
}

case "$1" in
  all)
    echo "Avvio tutti gli agenti..."
    for agent in alessio stefano walter veronica alessandra marwen; do
      open_tab "$agent"
      sleep 0.4
    done
    echo "Pronti."
    ;;
  alessio|ceo)        open_tab "alessio" ;;
  stefano|engineer)   open_tab "stefano" ;;
  walter|product)     open_tab "walter" ;;
  veronica|marketing) open_tab "veronica" ;;
  alessandra|uiux)    open_tab "alessandra" ;;
  marwen|tester)      open_tab "marwen" ;;
  *)
    echo "Uso: ./agents/iterm.sh <agente|all>"
    echo ""
    echo "  alessio    — sfondo rosso scuro    (CEO)"
    echo "  stefano    — sfondo blu scuro      (Engineer)"
    echo "  walter     — sfondo verde scuro    (Product)"
    echo "  veronica   — sfondo viola scuro    (Marketing)"
    echo "  alessandra — sfondo teal scuro     (UI/UX)"
    echo "  marwen     — sfondo arancione sc.  (Tester)"
    echo "  all        — lancia tutti"
    ;;
esac
