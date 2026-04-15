#!/bin/bash
# dashboard.sh — Dashboard agenti: status corrente + task in coda
# Uso: ./agents/dashboard.sh
#
# Alessio: chiama questo script quando vuoi sapere chi sta lavorando,
# cosa sta facendo, e quanti task ha ancora in coda ogni agente.
#
# CODA = task esplicitamente accodati con qtask.sh add (non messaggi inbox)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUS_FILE="$SCRIPT_DIR/../shared-context/AGENT-STATUS.json"
QUEUES_DIR="$SCRIPT_DIR/../shared-context/queues"

python3 << PYEOF
import json, os
from datetime import datetime

STATUS_FILE = "$STATUS_FILE"
QUEUES_DIR  = "$QUEUES_DIR"

AGENTS = [
    ("alessio",    "Alessio",    "CEO"),
    ("stefano",    "Stefano",    "Eng"),
    ("walter",     "Walter",     "Prod"),
    ("veronica",   "Veronica",   "Mkt"),
    ("alessandra", "Alessandra", "UX"),
    ("marwen",     "Marwen",     "QA"),
]

# ── Carica status ─────────────────────────────────────────────────────────────
try:
    with open(STATUS_FILE) as f:
        sdata = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    sdata = {}

# ── Conta task in coda (accodati esplicitamente con qtask.sh add) ─────────────
def queue_count(agent):
    path = os.path.join(QUEUES_DIR, f"{agent}.json")
    if not os.path.isfile(path):
        return 0
    try:
        with open(path) as f:
            return len(json.load(f))
    except (json.JSONDecodeError, OSError):
        return 0

STATUS_ICON = {
    "WORKING": "● WORKING",
    "IDLE":    "○ IDLE   ",
    "STANDBY": "◌ STANDBY",
}

now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
W = 62

print()
print("  " + "━" * W)
print(f"  THE OFFICE — DASHBOARD{now:>{W - 22}}")
print("  " + "━" * W)
print(f"  {'AGENTE':<16}  {'RUOLO':<4}  {'STATUS':<9}  {'CODA':>5}  TASK CORRENTE")
print(f"  {'─'*16}  {'─'*4}  {'─'*9}  {'─'*5}  {'─'*26}")

totals    = {"WORKING": 0, "IDLE": 0, "STANDBY": 0}
total_q   = 0

for (agent, name, role) in AGENTS:
    s      = sdata.get(agent, {"status": "STANDBY", "task": "", "ts": ""})
    status = s.get("status", "STANDBY")
    task   = s.get("task", "") or "—"
    q      = queue_count(agent)
    icon   = STATUS_ICON.get(status, "◌ STANDBY")
    totals[status] = totals.get(status, 0) + 1
    total_q += q
    q_str = f"[{q}]" if q > 0 else "[ ]"
    if len(task) > 26:
        task = task[:23] + "..."
    print(f"  {name:<16}  {role:<4}  {icon}  {q_str:>5}  {task}")

print("  " + "━" * W)
summary = (f"  WORKING: {totals['WORKING']}   "
           f"IDLE: {totals['IDLE']}   "
           f"STANDBY: {totals['STANDBY']}   "
           f"TASK IN CODA: {total_q}")
print(summary)
print("  " + "━" * W)
print()
PYEOF
