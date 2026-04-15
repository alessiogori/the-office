#!/bin/bash
# setstatus.sh — Aggiorna lo status di un agente nel dashboard centrale
# Uso:     ./agents/setstatus.sh <agente> <WORKING|IDLE|STANDBY> ["task corrente"]
# Esempio: ./agents/setstatus.sh stefano WORKING "Fix BUG-047 su /checkout"
#          ./agents/setstatus.sh stefano IDLE

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUS_FILE="$SCRIPT_DIR/../shared-context/AGENT-STATUS.json"

AGENT=$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')
STATUS=$(echo "${2:-}" | tr '[:lower:]' '[:upper:]')
TASK="${3:-}"

# ── Validazione ───────────────────────────────────────────────────────────────
if [[ -z "$AGENT" || -z "$STATUS" ]]; then
  echo "Uso: ./agents/setstatus.sh <agente> <WORKING|IDLE|STANDBY> [\"task corrente\"]"
  echo "Agenti: alessio, stefano, walter, veronica, alessandra, marwen"
  exit 1
fi

case "$AGENT" in
  alessio|stefano|walter|veronica|alessandra|marwen) ;;
  *) echo "Errore: agente '$AGENT' non riconosciuto."; exit 1 ;;
esac

case "$STATUS" in
  WORKING|IDLE|STANDBY) ;;
  *) echo "Errore: status '$STATUS' non valido. Usa: WORKING, IDLE, STANDBY"; exit 1 ;;
esac

if [[ "$STATUS" == "WORKING" && -z "$TASK" ]]; then
  echo "Errore: WORKING richiede una descrizione del task."
  echo "Esempio: ./agents/setstatus.sh $AGENT WORKING \"Fix BUG-047 su /checkout\""
  exit 1
fi

# ── Inizializza il file se non esiste ────────────────────────────────────────
mkdir -p "$(dirname "$STATUS_FILE")"
if [[ ! -f "$STATUS_FILE" ]]; then
  python3 -c "
import json
agents = ['alessio','stefano','walter','veronica','alessandra','marwen']
data = {a: {'status':'STANDBY','task':'','ts':''} for a in agents}
with open('$STATUS_FILE','w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
"
fi

# ── Aggiorna lo status ────────────────────────────────────────────────────────
TIMESTAMP=$(date "+%Y-%m-%dT%H:%M:%S")

python3 -c "
import json, sys
with open('$STATUS_FILE') as f:
    data = json.load(f)
data['$AGENT'] = {'status': '$STATUS', 'task': sys.argv[1], 'ts': '$TIMESTAMP'}
with open('$STATUS_FILE', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
" "$TASK"

echo "  ✓ $AGENT → $STATUS${TASK:+ (\"$TASK\")}"
