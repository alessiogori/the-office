#!/usr/bin/env bash
# team.sh — accesso al manifest del team (shared-context/TEAM.json).
# Sourceata da ogni script che deve sapere chi c'è nel team.
#
# Uso:
#   source "$(dirname "$0")/lib/team.sh"
#   team_validate stefano || exit 1
#   NOME=$(team_get stefano name)

TEAM_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

team_manifest_path() {
  if [ -n "${OFFICE_TEAM_FILE:-}" ]; then
    echo "$OFFICE_TEAM_FILE"
  elif [ -n "${OFFICE_SHARED_DIR:-}" ]; then
    echo "$OFFICE_SHARED_DIR/TEAM.json"
  else
    echo "$TEAM_LIB_DIR/../../shared-context/TEAM.json"
  fi
}

team_require_manifest() {
  local manifest
  manifest="$(team_manifest_path)"

  if [ ! -f "$manifest" ]; then
    echo "Errore: $manifest non trovato." >&2
    echo "Questo progetto non ha un team configurato. Lancia ./setup.sh per crearlo." >&2
    exit 2
  fi

  if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$manifest" >/dev/null 2>&1; then
    echo "Errore: $manifest non è un JSON valido." >&2
    echo "Correggi il file a mano oppure rigeneralo con ./setup.sh." >&2
    exit 2
  fi
}

team_ids() {
  team_require_manifest
  python3 - "$(team_manifest_path)" <<'PY' 2>/dev/null
import json, sys
for m in json.load(open(sys.argv[1])).get("team", []):
    print(m["id"])
PY
}

team_get() {
  local id="$1" field="$2"
  team_require_manifest
  python3 - "$(team_manifest_path)" "$id" "$field" <<'PY' 2>/dev/null
import json, sys
path, wanted, field = sys.argv[1], sys.argv[2], sys.argv[3]
for m in json.load(open(path)).get("team", []):
    if m.get("id") == wanted:
        v = m.get(field)
        if v is None:
            print("")
        elif isinstance(v, bool):
            print("true" if v else "false")
        else:
            print(v)
        sys.exit(0)
sys.exit(1)
PY
}

team_validate() {
  local id="$1"
  team_require_manifest

  # -F: un id come "marwe." non deve combaciare per via del punto.
  if team_ids | grep -qxF -- "$id"; then
    return 0
  fi

  echo "Errore: agente '$id' non riconosciuto." >&2
  echo "Agenti del team: $(team_ids | tr '\n' ' ')" >&2
  return 1
}

team_coordinators() {
  team_require_manifest
  python3 - "$(team_manifest_path)" <<'PY' 2>/dev/null
import json, sys
for m in json.load(open(sys.argv[1])).get("team", []):
    if m.get("coordinator"):
        print(m["id"])
PY
}
