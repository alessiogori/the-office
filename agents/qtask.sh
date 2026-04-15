#!/bin/bash
# qtask.sh — Gestione coda task di un agente
#
# Un task va in coda quando arriva mentre l'agente è già WORKING su altro.
# La coda è visibile ad Alessio via ./agents/dashboard.sh
#
# Uso:
#   ./agents/qtask.sh add  <agente> "descrizione task"   → accoda, stampa ID
#   ./agents/qtask.sh done <agente> <task-id>            → rimuove dalla coda
#   ./agents/qtask.sh list <agente>                      → lista task pendenti

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUEUES_DIR="$SCRIPT_DIR/../shared-context/queues"

CMD=$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')
AGENT=$(echo "${2:-}" | tr '[:upper:]' '[:lower:]')

# ── Validazione ───────────────────────────────────────────────────────────────
usage() {
  echo "Uso:"
  echo "  ./agents/qtask.sh add  <agente> \"descrizione task\""
  echo "  ./agents/qtask.sh done <agente> <task-id>"
  echo "  ./agents/qtask.sh list <agente>"
  echo "Agenti: alessio, stefano, walter, veronica, alessandra, marwen"
  exit 1
}

[[ -z "$CMD" || -z "$AGENT" ]] && usage

case "$AGENT" in
  alessio|stefano|walter|veronica|alessandra|marwen) ;;
  *) echo "Errore: agente '$AGENT' non riconosciuto."; exit 1 ;;
esac

mkdir -p "$QUEUES_DIR"
QUEUE_FILE="$QUEUES_DIR/$AGENT.json"

[[ ! -f "$QUEUE_FILE" ]] && echo "[]" > "$QUEUE_FILE"

# ── Comandi ───────────────────────────────────────────────────────────────────
case "$CMD" in

  add)
    TASK="${3:-}"
    if [[ -z "$TASK" ]]; then
      echo "Errore: descrizione task obbligatoria."
      echo "Uso: ./agents/qtask.sh add $AGENT \"descrizione task\""
      exit 1
    fi
    TIMESTAMP=$(date "+%Y-%m-%dT%H:%M:%S")
    TASK_ID="task-$(date +%Y%m%d-%H%M%S)"
    python3 -c "
import json, sys
with open('$QUEUE_FILE') as f:
    q = json.load(f)
q.append({'id': '$TASK_ID', 'ts': '$TIMESTAMP', 'task': sys.argv[1]})
with open('$QUEUE_FILE', 'w') as f:
    json.dump(q, f, indent=2, ensure_ascii=False)
print(f'  Task accodato: $TASK_ID')
print(f'  Coda $AGENT: {len(q)} task pendenti')
" "$TASK"
    ;;

  done)
    TASK_ID="${3:-}"
    if [[ -z "$TASK_ID" ]]; then
      echo "Errore: task-id obbligatorio."
      echo "Uso: ./agents/qtask.sh done $AGENT <task-id>"
      exit 1
    fi
    python3 -c "
import json, sys
with open('$QUEUE_FILE') as f:
    q = json.load(f)
before = len(q)
q_new = [t for t in q if t.get('id') != '$TASK_ID']
if len(q_new) == before:
    print('Errore: task-id \"$TASK_ID\" non trovato in coda.')
    sys.exit(1)
with open('$QUEUE_FILE', 'w') as f:
    json.dump(q_new, f, indent=2, ensure_ascii=False)
print(f'  ✓ Rimosso dalla coda: $TASK_ID')
print(f'  Coda $AGENT: {len(q_new)} task rimanenti')
"
    ;;

  list)
    python3 -c "
import json
with open('$QUEUE_FILE') as f:
    q = json.load(f)
if not q:
    print('  Coda $AGENT: vuota.')
else:
    print(f'  Coda $AGENT ({len(q)} task pendenti):')
    for i, t in enumerate(q, 1):
        print(f'  {i}. {t[\"id\"]}')
        print(f'     {t[\"task\"]}')
        print(f'     accodato: {t[\"ts\"]}')
"
    ;;

  *)
    usage
    ;;
esac
