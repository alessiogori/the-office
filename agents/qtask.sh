#!/bin/bash
# qtask.sh — Gestione coda task di un agente
#
# Un task va in coda quando arriva mentre l'agente è già WORKING su altro.
# La coda è visibile al coordinatore via ./agents/dashboard.sh
#
# Uso:
#   ./agents/qtask.sh add  <agente> "descrizione task"   → accoda, stampa ID
#   ./agents/qtask.sh done <agente> <task-id>            → rimuove dalla coda
#   ./agents/qtask.sh list <agente>                      → lista task pendenti

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/team.sh"

SHARED_DIR="${OFFICE_SHARED_DIR:-$SCRIPT_DIR/../shared-context}"
QUEUES_DIR="$SHARED_DIR/queues"

CMD=$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')
AGENT=$(echo "${2:-}" | tr '[:upper:]' '[:lower:]')

# ── Validazione ───────────────────────────────────────────────────────────────
usage() {
  echo "Uso:" >&2
  echo "  ./agents/qtask.sh add  <agente> \"descrizione task\"" >&2
  echo "  ./agents/qtask.sh done <agente> <task-id>" >&2
  echo "  ./agents/qtask.sh list <agente>" >&2
  echo "Agenti: $(team_ids | tr '\n' ' ')" >&2
  exit 1
}

[[ -z "$CMD" || -z "$AGENT" ]] && usage

team_validate "$AGENT" || exit 1

mkdir -p "$QUEUES_DIR"
QUEUE_FILE="$QUEUES_DIR/$AGENT.json"

[[ ! -f "$QUEUE_FILE" ]] && echo "[]" > "$QUEUE_FILE"

# ── Comandi ───────────────────────────────────────────────────────────────────
case "$CMD" in

  add)
    TASK="${3:-}"
    if [[ -z "$TASK" ]]; then
      echo "Errore: descrizione task obbligatoria." >&2
      echo "Uso: ./agents/qtask.sh add $AGENT \"descrizione task\"" >&2
      exit 1
    fi
    python3 - "$QUEUE_FILE" "$AGENT" "$TASK" <<'PY'
import json, os, sys, time
path, agent, task = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    q = json.load(f)
now = time.localtime()
stamp = time.strftime("%Y%m%d-%H%M%S", now)
# Suffisso progressivo: due accodamenti nello stesso secondo devono restare
# distinguibili, altrimenti "qtask done" ne rimuoverebbe due invece di uno.
existing = {t.get("id", "") for t in q}
task_id = f"task-{stamp}"
n = 1
while task_id in existing:
    n += 1
    task_id = f"task-{stamp}-{n}"
q.append({"id": task_id, "ts": time.strftime("%Y-%m-%dT%H:%M:%S", now), "task": task})
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(q, f, indent=2, ensure_ascii=False)
os.replace(tmp, path)
print(f"  Task accodato: {task_id}")
print(f"  Coda {agent}: {len(q)} task pendenti")
PY
    ;;

  done)
    TASK_ID="${3:-}"
    if [[ -z "$TASK_ID" ]]; then
      echo "Errore: task-id obbligatorio." >&2
      echo "Uso: ./agents/qtask.sh done $AGENT <task-id>" >&2
      exit 1
    fi
    python3 - "$QUEUE_FILE" "$AGENT" "$TASK_ID" <<'PY'
import json, os, sys
path, agent, task_id = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    q = json.load(f)
remaining = [t for t in q if t.get("id") != task_id]
if len(remaining) == len(q):
    print(f"Errore: task-id '{task_id}' non trovato in coda.", file=sys.stderr)
    sys.exit(1)
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(remaining, f, indent=2, ensure_ascii=False)
os.replace(tmp, path)
print(f"  ✓ Rimosso dalla coda: {task_id}")
print(f"  Coda {agent}: {len(remaining)} task rimanenti")
PY
    ;;

  list)
    python3 - "$QUEUE_FILE" "$AGENT" <<'PY'
import json, sys
path, agent = sys.argv[1], sys.argv[2]
with open(path) as f:
    q = json.load(f)
if not q:
    print(f"  Coda {agent}: vuota.")
else:
    print(f"  Coda {agent} ({len(q)} task pendenti):")
    for i, t in enumerate(q, 1):
        print(f"  {i}. {t['id']}")
        print(f"     {t['task']}")
        print(f"     accodato: {t['ts']}")
PY
    ;;

  *)
    usage
    ;;
esac
