#!/bin/bash
# pre-tool.sh — Hook PreToolUse per Claude Code.
# Marca l'agente WORKING quando esegue tool. Richiede env var OFFICE_AGENT.
#
# Configura in .claude/settings.json:
#   {
#     "hooks": {
#       "PreToolUse": [{ "hooks": [{ "type": "command",
#         "command": "$CLAUDE_PROJECT_DIR/agents/claude-hooks/pre-tool.sh" }] }],
#       "Stop": [{ "hooks": [{ "type": "command",
#         "command": "$CLAUDE_PROJECT_DIR/agents/claude-hooks/stop.sh" }] }]
#     }
#   }
# E avvia sessione con: OFFICE_AGENT=stefano claude

[[ -z "$OFFICE_AGENT" ]] && exit 0

INPUT=$(cat)
TOOL=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null)
TASK="${TOOL:-task in corso}"

"$CLAUDE_PROJECT_DIR/agents/setstatus.sh" "$OFFICE_AGENT" WORKING "$TASK" >/dev/null 2>&1
exit 0
