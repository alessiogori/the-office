#!/bin/bash
# dashboard.sh — Dashboard agenti: status corrente + coda inbox
# Uso: ./agents/dashboard.sh
#
# Alessio: chiama questo script quando vuoi sapere chi sta lavorando,
# cosa sta facendo, e quanti messaggi ha in coda ogni agente.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUS_FILE="$SCRIPT_DIR/../shared-context/AGENT-STATUS.json"
INBOX_DIR="$SCRIPT_DIR/../shared-context/inbox"

python3 << PYEOF
import json, os
from datetime import datetime

STATUS_FILE = "$STATUS_FILE"
INBOX_DIR   = "$INBOX_DIR"

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

# ── Conta messaggi inbox (= task in coda) ────────────────────────────────────
def inbox_count(agent):
    path = os.path.join(INBOX_DIR, agent)
    if not os.path.isdir(path):
        return 0
    return len([f for f in os.listdir(path) if f.endswith(".md")])

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
print(f"  {'AGENTE':<16}  {'RUOLO':<4}  {'STATUS':<9}  {'INBOX':>5}  TASK CORRENTE")
print(f"  {'─'*16}  {'─'*4}  {'─'*9}  {'─'*5}  {'─'*26}")

totals     = {"WORKING": 0, "IDLE": 0, "STANDBY": 0}
total_inbox = 0

for (agent, name, role) in AGENTS:
    s      = sdata.get(agent, {"status": "STANDBY", "task": "", "ts": ""})
    status = s.get("status", "STANDBY")
    task   = s.get("task", "") or "—"
    inbox  = inbox_count(agent)
    icon   = STATUS_ICON.get(status, "◌ STANDBY")
    totals[status] = totals.get(status, 0) + 1
    total_inbox   += inbox
    inbox_str = f"[{inbox}]" if inbox > 0 else "[ ]"
    if len(task) > 26:
        task = task[:23] + "..."
    print(f"  {name:<16}  {role:<4}  {icon}  {inbox_str:>5}  {task}")

print("  " + "━" * W)
summary = (f"  WORKING: {totals['WORKING']}   "
           f"IDLE: {totals['IDLE']}   "
           f"STANDBY: {totals['STANDBY']}   "
           f"INBOX TOTALE: {total_inbox}")
print(summary)
print("  " + "━" * W)
print()
PYEOF
