#!/usr/bin/env bash
# The Office — Launch agent
# Uso: ./agents/launch.sh [--dry-run] <agente>
# Esempio: ./agents/launch.sh stefano

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/team.sh"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DRY_RUN=""
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
  shift
fi

AGENT=$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')

if [ -z "$AGENT" ]; then
  echo "Agenti disponibili:"
  team_ids | while read -r id; do
    printf "  %-12s (%s)\n" "$id" "$(team_get "$id" label)"
  done
  echo ""
  echo "Uso: ./agents/launch.sh <agente>"
  exit 0
fi

team_validate "$AGENT" || exit 1

NAME=$(team_get "$AGENT" name)
LABEL=$(team_get "$AGENT" label)
FOLDER=$(team_get "$AGENT" folder)

WAIT_MSG="Poi rispondi con un unico messaggio di ready (es: '$NAME pronto. In attesa del via.') e NON fare nient'altro: nessuna analisi, nessun file aggiuntivo, nessuna proposta. Aspetta il primo comando esplicito."

SOUL_MSG="Se $FOLDER/SOUL.md non esiste, scrivilo prima seguendo agents/_authoring/SOUL-AUTHORING.md e $FOLDER/ROLE-BRIEF.md, poi dichiara che l'hai appena forgiato."

PROMPT="Sei $NAME, $LABEL. Leggi $FOLDER/SOUL.md e $FOLDER/IDENTITY.md. $SOUL_MSG $WAIT_MSG"

if [ -n "$DRY_RUN" ]; then
  echo "$PROMPT"
  exit 0
fi

cd "$PROJECT_DIR" || exit 1
claude "$PROMPT"
