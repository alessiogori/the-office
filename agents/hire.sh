#!/usr/bin/env bash
# hire.sh — aggiunge una persona a un team esistente.
#
# Uso:
#   ./agents/hire.sh                    interattivo (richiede gum)
#   ./agents/hire.sh <ruolo> "<Nome>"   diretto, senza gum
#
# I ruoli disponibili sono in catalog/roles.json. Se serve una figura che il
# catalogo non copre, aggiungi una voce lì: hire.sh la vede subito.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/team.sh"
source "$SCRIPT_DIR/lib/roster.sh"

SHARED_DIR="${OFFICE_SHARED_DIR:-$SCRIPT_DIR/../shared-context}"
AGENTS_DIR="${OFFICE_AGENTS_DIR:-$SCRIPT_DIR}"

team_require_manifest
TEAM_JSON="$(team_manifest_path)"

SLUG="${1:-}"
NAME="${2:-}"

# ── Raccolta interattiva, solo se mancano gli argomenti ──────────────────────
if [ -z "$SLUG" ] || [ -z "$NAME" ]; then
  source "$SCRIPT_DIR/lib/tui.sh"
  tui_require_gum
  SLUG=$(tui_pick_role "Che ruolo ha la persona che stai aggiungendo?") \
    || { echo "Selezione annullata." >&2; exit 2; }
  NAME=$(tui_ask_name "")
  [ -n "$NAME" ] || { echo "Nome obbligatorio." >&2; exit 2; }
fi

# ── Validazione, prima di toccare qualsiasi file ─────────────────────────────
LABEL=$(roster_role_get "$SLUG" label 2>/dev/null)
if [ -z "$LABEL" ]; then
  echo "Errore: ruolo '$SLUG' non presente nel catalogo." >&2
  echo "Ruoli disponibili: $(roster_slugs | tr '\n' ' ')" >&2
  exit 2
fi

ID=$(roster_id_from_name "$NAME")
if [ -z "$ID" ]; then
  echo "Errore: il nome '$NAME' non produce un id valido." >&2
  exit 2
fi

if team_ids | grep -qxF -- "$ID"; then
  echo "Errore: '$ID' è già nel team." >&2
  echo "Scegli un nome diverso: gli id devono essere univoci." >&2
  exit 2
fi

# ── Rollback: i passi seguenti toccano file che altri agenti stanno leggendo ──
PERSON_DIR="$AGENTS_DIR/$ID"
CREATED_DIR=""

MANIFEST_WRITTEN=""

rollback() {
  [ -n "$CREATED_DIR" ] && [ -d "$CREATED_DIR" ] && rm -rf "$CREATED_DIR"
  rm -rf "$SHARED_DIR/inbox/$ID" 2>/dev/null
  rm -f "$SHARED_DIR/queues/$ID.json" 2>/dev/null

  # La voce nel manifest va tolta, altrimenti resta un agente fantasma che
  # punta a una cartella cancellata e che ogni script continua a vedere.
  if [ -n "$MANIFEST_WRITTEN" ]; then
    python3 - "$TEAM_JSON" "$ID" <<'ROLLBACK' 2>/dev/null
import json, os, sys
path, id_ = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(path))
except Exception:
    sys.exit(0)
data["team"] = [m for m in data.get("team", []) if m.get("id") != id_]
tmp = path + ".tmp"
json.dump(data, open(tmp, "w"), indent=2, ensure_ascii=False)
os.replace(tmp, path)
ROLLBACK
  fi
  return 0
}
trap 'rollback' EXIT

# ── 1. Cartella persona ───────────────────────────────────────────────────────
if ! roster_generate_person "$SLUG" "$NAME" "$ID" "$AGENTS_DIR" "$TEAM_JSON"; then
  echo "Errore: generazione della cartella fallita." >&2
  exit 1
fi
CREATED_DIR="$PERSON_DIR"

# ── 2. Manifest (scrittura atomica) ───────────────────────────────────────────
COLOR=$(roster_next_color "$TEAM_JSON")
LOG=$(roster_role_get "$SLUG" log)
COORD=$(roster_role_get "$SLUG" coordinator)

if ! python3 - "$TEAM_JSON" "$ID" "$NAME" "$SLUG" "$LABEL" "$LOG" "$COLOR" "$COORD" <<'PY' 2>/dev/null
import json, os, sys
path, id_, name, role, label, log, color, coord = sys.argv[1:9]
data = json.load(open(path))
data["team"].append({
    "id": id_, "name": name, "role": role, "label": label,
    "folder": f"agents/{id_}", "log": log or None,
    "color": color, "coordinator": coord == "true",
})
tmp = path + ".tmp"
json.dump(data, open(tmp, "w"), indent=2, ensure_ascii=False)
os.replace(tmp, path)
PY
then
  echo "Errore: scrittura di $TEAM_JSON fallita. Nessuna modifica applicata." >&2
  exit 1
fi
MANIFEST_WRITTEN=1

# ── 3. Stato, inbox, coda ─────────────────────────────────────────────────────
if ! mkdir -p "$SHARED_DIR/inbox/$ID" "$SHARED_DIR/queues" 2>/dev/null; then
  echo "Errore: impossibile creare inbox e coda in $SHARED_DIR." >&2
  exit 1
fi
echo "[]" > "$SHARED_DIR/queues/$ID.json"

STATUS_FILE="$SHARED_DIR/AGENT-STATUS.json"
if ! python3 - "$STATUS_FILE" "$ID" <<'PY' 2>/dev/null
import json, os, sys
path, id_ = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(path))
except Exception:
    data = {}
data[id_] = {"status": "STANDBY", "task": "", "ts": ""}
tmp = path + ".tmp"
json.dump(data, open(tmp, "w"), indent=2, ensure_ascii=False)
os.replace(tmp, path)
PY
then
  echo "Errore: aggiornamento di AGENT-STATUS.json fallito." >&2
  exit 1
fi

# Tutto riuscito: disarma il rollback.
trap - EXIT

echo ""
echo "  ✓ $NAME ($LABEL) aggiunto al team come '$ID'"
echo ""
echo "  Restano due passi:"
echo "    1. Apri il suo terminale:  ./agents/iterm.sh $ID"
echo "    2. Avvisa il team:         ./agents/msg.sh <tu> $ID \"Benvenuto. Leggi il tuo ROLE-BRIEF.md.\""
echo ""
echo "  Il suo SOUL.md verrà scritto al primo avvio."
