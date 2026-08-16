#!/usr/bin/env bash
# The Office — iTerm2 window launcher
# Crea una finestra iTerm2 separata per ogni agente con colore di sfondo distinto.
# Uso: ./agents/iterm.sh [--dry-run] <agente|all|dashboard>
#
# Ogni finestra riceve un nome di sessione esplicito (il nome della persona nel
# manifest), in modo che msg.sh e ack.sh possano trovarla in modo affidabile con:
#   name of aSession contains "<nome>"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/team.sh"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DRY_RUN=""
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
  shift
fi

TARGET="${1:-}"

# Il colore del manifest è l'accento dell'agente: vivace, illeggibile come
# sfondo. Lo scuriamo al 18% per ottenere lo sfondo della finestra, così resta
# riconoscibile senza bruciare gli occhi. Una sola sorgente di verità.
darken() {
  local hex="${1#\#}"
  python3 - "$hex" <<'PY'
import sys
h = sys.argv[1]
r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
print("%02x%02x%02x" % (int(r * 0.18), int(g * 0.18), int(b * 0.18)))
PY
}

open_window() {
  local agent="$1"
  local name role accent bg r g b

  name=$(team_get "$agent" name)
  role=$(team_get "$agent" label)
  accent=$(team_get "$agent" color)
  accent="${accent#\#}"
  # Un manifest scritto a mano può avere un colore mancante o troncato:
  # meglio un grigio neutro che un errore aritmetico e un AppleScript rotto.
  case "$accent" in
    [0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]) ;;
    *) accent="7f8c8d" ;;
  esac
  bg=$(darken "$accent")

  if [ -n "$DRY_RUN" ]; then
    echo "$agent  $name  $role  accent=$accent  bg=$bg  $(team_get "$agent" folder)"
    return 0
  fi

  # hex → 0-65535 per AppleScript (ogni canale * 257)
  r=$(( 16#${bg:0:2} * 257 ))
  g=$(( 16#${bg:2:2} * 257 ))
  b=$(( 16#${bg:4:2} * 257 ))

  osascript <<APPLESCRIPT
tell application "iTerm2"
  activate
  -- Crea sempre una nuova finestra dedicata (non un tab)
  set w to (create window with default profile)
  tell current session of current tab of w
    -- Imposta il nome sessione: usato da msg.sh/ack.sh per il lookup
    set name to "$name"
    set background color to {$r, $g, $b}
    write text "cd '$PROJECT_DIR' && ./agents/launch.sh $agent"
  end tell
end tell
APPLESCRIPT

  echo "  ✓ $role — $name"
}

open_dashboard_window() {
  if [ -n "$DRY_RUN" ]; then
    echo "dashboard  Dashboard  live  bg=050810"
    return 0
  fi

  # #050810 — blu-nero profondo, stile monitor di controllo
  local r=$(( 16#05 * 257 ))
  local g=$(( 16#08 * 257 ))
  local b=$(( 16#10 * 257 ))

  osascript <<APPLESCRIPT
tell application "iTerm2"
  activate
  set w to (create window with default profile)
  tell current session of current tab of w
    set name to "Dashboard"
    set background color to {$r, $g, $b}
    write text "cd '$PROJECT_DIR' && ./agents/live-dashboard.sh"
  end tell
end tell
APPLESCRIPT

  echo "  ✓ Dashboard (live)"
}

usage() {
  echo "Uso: ./agents/iterm.sh [--dry-run] <agente|all|dashboard>"
  echo ""
  team_ids | while read -r id; do
    printf "  %-12s — %s\n" "$id" "$(team_get "$id" label)"
  done
  echo "  dashboard    — Live Dashboard"
  echo "  all          — lancia tutti + dashboard"
}

case "$TARGET" in
  "")
    usage
    ;;
  all)
    [ -z "$DRY_RUN" ] && echo "Avvio tutti gli agenti + dashboard..."
    open_dashboard_window
    [ -z "$DRY_RUN" ] && sleep 0.4
    team_ids | while read -r id; do
      open_window "$id"
      [ -z "$DRY_RUN" ] && sleep 0.4
    done
    [ -z "$DRY_RUN" ] && echo "Pronti."
    ;;
  dashboard)
    open_dashboard_window
    ;;
  *)
    team_validate "$TARGET" || { echo ""; usage; exit 1; }
    open_window "$TARGET"
    ;;
esac
