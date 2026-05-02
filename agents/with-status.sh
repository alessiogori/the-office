#!/bin/bash
# with-status.sh — Esegue un comando segnando lo status dell'agente in WORKING e poi IDLE.
# Uso:    ./agents/with-status.sh <agente> "<descrizione task>" -- <comando> [args...]
# Esempi:
#   ./agents/with-status.sh stefano "Fix BUG-047" -- npm test
#   ./agents/with-status.sh marwen "E2E checkout" -- bun run e2e

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT="${1:-}"
TASK="${2:-}"
SEP="${3:-}"

if [[ -z "$AGENT" || -z "$TASK" || "$SEP" != "--" ]]; then
  echo "Uso: $0 <agente> \"<task>\" -- <comando> [args...]"
  exit 1
fi

shift 3

cleanup() {
  "$SCRIPT_DIR/setstatus.sh" "$AGENT" IDLE >/dev/null
}
trap cleanup EXIT INT TERM

"$SCRIPT_DIR/setstatus.sh" "$AGENT" WORKING "$TASK" >/dev/null
"$@"
