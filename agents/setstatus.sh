#!/bin/bash
# setstatus.sh — Aggiorna lo status di un agente nel dashboard centrale
# Uso:     ./agents/setstatus.sh <agente> <WORKING|IDLE|STANDBY> ["task corrente"]
# Esempio: ./agents/setstatus.sh stefano WORKING "Fix BUG-047 su /checkout"
#          ./agents/setstatus.sh stefano IDLE

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/team.sh"

SHARED_DIR="${OFFICE_SHARED_DIR:-$SCRIPT_DIR/../shared-context}"
STATUS_FILE="$SHARED_DIR/AGENT-STATUS.json"

AGENT=$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')
STATUS=$(echo "${2:-}" | tr '[:lower:]' '[:upper:]')
TASK="${3:-}"

# ── Validazione ───────────────────────────────────────────────────────────────
if [[ -z "$AGENT" || -z "$STATUS" ]]; then
  echo "Uso: ./agents/setstatus.sh <agente> <WORKING|IDLE|STANDBY> [\"task corrente\"]" >&2
  echo "Agenti: $(team_ids | tr '\n' ' ')" >&2
  exit 1
fi

team_validate "$AGENT" || exit 1

case "$STATUS" in
  WORKING|IDLE|STANDBY) ;;
  *) echo "Errore: status '$STATUS' non valido. Usa: WORKING, IDLE, STANDBY" >&2; exit 1 ;;
esac

if [[ "$STATUS" == "WORKING" && -z "$TASK" ]]; then
  echo "Errore: WORKING richiede una descrizione del task." >&2
  echo "Esempio: ./agents/setstatus.sh $AGENT WORKING \"Fix BUG-047 su /checkout\"" >&2
  exit 1
fi

mkdir -p "$SHARED_DIR"

# ── Inizializza il file con gli agenti del manifest ──────────────────────────
if [[ ! -f "$STATUS_FILE" ]]; then
  # Gli id passano da argv, non da stdin: "python3 -" usa stdin per il programma.
  python3 - "$STATUS_FILE" $(team_ids | tr '\n' ' ') <<'PY'
import json, os, sys
path, ids = sys.argv[1], sys.argv[2:]
data = {a: {"status": "STANDBY", "task": "", "ts": ""} for a in ids}
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
os.replace(tmp, path)
PY
fi

# ── Aggiorna lo status (scrittura atomica) ───────────────────────────────────
TIMESTAMP=$(date "+%Y-%m-%dT%H:%M:%S")

python3 - "$STATUS_FILE" "$AGENT" "$STATUS" "$TIMESTAMP" "$TASK" <<'PY'
import json, os, sys
path, agent, status, ts, task = sys.argv[1:6]
with open(path) as f:
    data = json.load(f)
data[agent] = {"status": status, "task": task, "ts": ts}
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
os.replace(tmp, path)
PY

echo "  ✓ $AGENT → $STATUS${TASK:+ (\"$TASK\")}"
