#!/bin/bash
# stop.sh — Hook Stop per Claude Code. Marca l'agente IDLE a fine turno.

[[ -z "$OFFICE_AGENT" ]] && exit 0
"$CLAUDE_PROJECT_DIR/agents/setstatus.sh" "$OFFICE_AGENT" IDLE >/dev/null 2>&1
exit 0
