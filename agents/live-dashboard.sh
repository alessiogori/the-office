#!/bin/bash
# live-dashboard.sh — Dashboard live con colori ANSI e auto-refresh
# Uso: ./agents/live-dashboard.sh
#      REFRESH=10 ./agents/live-dashboard.sh   (intervallo personalizzato)
#
# Ctrl+C per uscire (ripristina il terminale automaticamente)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/team.sh"

team_require_manifest

SHARED_DIR="${OFFICE_SHARED_DIR:-$SCRIPT_DIR/../shared-context}"
MANIFEST="$(team_manifest_path)"
STATUS_FILE="$SHARED_DIR/AGENT-STATUS.json"
QUEUES_DIR="$SHARED_DIR/queues"
REFRESH="${REFRESH:-5}"

SPIN=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
si=0

# ── Cleanup: ripristina terminale su Ctrl+C ───────────────────────────────────
cleanup() {
  tput cnorm   # mostra cursore
  tput rmcup   # ripristina schermo precedente
  echo
  exit 0
}
trap cleanup INT TERM

tput smcup   # salva schermo corrente
tput civis   # nascondi cursore

# ── Loop principale ───────────────────────────────────────────────────────────
while true; do
  tput cup 0 0  # torna all'inizio senza flash
  tput ed       # pulisce fino a fine schermo

  SC="${SPIN[$si]}"

  python3 << PYEOF
import json, os
from datetime import datetime

MANIFEST    = "$MANIFEST"
STATUS_FILE = "$STATUS_FILE"
QUEUES_DIR  = "$QUEUES_DIR"
SC          = "$SC"

# ── Colori ANSI ───────────────────────────────────────────────────────────────
R   = "\033[0m"      # reset
B   = "\033[1m"      # bold
DIM = "\033[2m"      # dim
BG  = "\033[1;32m"   # bold green   — WORKING
YL  = "\033[33m"     # yellow       — IDLE
GR  = "\033[90m"     # dark gray    — STANDBY
BR  = "\033[1;31m"   # bold red     — coda non vuota
CY  = "\033[1;36m"   # bold cyan    — separatori / header
WH  = "\033[1;37m"   # bold white   — nomi agenti
DW  = "\033[2;37m"   # dim white    — ruoli / task

STATUS_COLOR = {"WORKING": BG, "IDLE": YL, "STANDBY": GR}
STATUS_ICON  = {"WORKING": "● WORKING", "IDLE": "○ IDLE   ", "STANDBY": "◌ STANDBY"}

# Il team viene dal manifest: e' l'unica sorgente di verita'.
AGENTS = [(m["id"], m["name"], m["role"][:4].ljust(4))
          for m in json.load(open(MANIFEST))["team"]]

# ── Dati ──────────────────────────────────────────────────────────────────────
try:
    with open(STATUS_FILE) as f:
        sdata = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    sdata = {}

def queue_count(agent):
    path = os.path.join(QUEUES_DIR, f"{agent}.json")
    if not os.path.isfile(path):
        return 0
    try:
        with open(path) as f:
            return len(json.load(f))
    except (json.JSONDecodeError, OSError):
        return 0

# ── Rendering ─────────────────────────────────────────────────────────────────
now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
W   = 64
SEP = f"  {CY}{'━' * W}{R}"
LIN = f"  {DIM}{'─' * W}{R}"

print(SEP)
title   = f"  {B}{WH}THE OFFICE — LIVE DASHBOARD{R}  {GR}{SC}{R}"
ts_pad  = W - 30
print(f"{title}  {DW}{now:>{ts_pad}}{R}")
print(SEP)
print(f"  {DIM}{'AGENTE':<16}  {'RUOLO':<4}  {'STATUS':<9}  {'CODA':>5}  TASK CORRENTE{R}")
print(LIN)

totals  = {"WORKING": 0, "IDLE": 0, "STANDBY": 0}
total_q = 0

for (agent, name, role) in AGENTS:
    s      = sdata.get(agent, {"status": "STANDBY", "task": "", "ts": ""})
    status = s.get("status", "STANDBY")
    task   = s.get("task", "") or "—"
    q      = queue_count(agent)
    color  = STATUS_COLOR.get(status, GR)
    icon   = STATUS_ICON.get(status, "◌ STANDBY")
    totals[status] = totals.get(status, 0) + 1
    total_q += q
    q_str   = f"{BR}[{q}]{R}" if q > 0 else f"{DIM}[ ]{R}"
    if len(task) > 26:
        task = task[:23] + "..."
    print(f"  {WH}{name:<16}{R}  {DW}{role:<4}{R}  {color}{icon}{R}  {q_str:>5}  {DW}{task}{R}")

print(SEP)

wc, ic, sc = totals["WORKING"], totals["IDLE"], totals["STANDBY"]
q_label    = f"{BR}TASK IN CODA: {total_q}{R}" if total_q > 0 else f"{DIM}TASK IN CODA: 0{R}"
print(f"  {BG}WORKING: {wc}{R}   {YL}IDLE: {ic}{R}   {GR}STANDBY: {sc}{R}   {q_label}")
print(SEP)
print()
PYEOF

  # ── Countdown con spinner ─────────────────────────────────────────────────
  for (( t=REFRESH; t>0; t-- )); do
    printf "  \033[90m%s\033[0m  \033[2maggiornamento in: \033[1m%ds\033[0m\033[2m  —  Ctrl+C per uscire\033[0m   \r" \
      "${SPIN[$si]}" "$t"
    si=$(( (si + 1) % ${#SPIN[@]} ))
    sleep 1
  done
  printf "\r%${COLUMNS}s\r" ""  # pulisce la riga countdown

done
