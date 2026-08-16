#!/usr/bin/env bash
# roster.sh — accesso al catalogo dei ruoli e generazione delle cartelle persona.
# Serve solo a setup.sh e hire.sh: gli script di uso quotidiano caricano team.sh,
# che risponde a "chi c'è nel team" invece che a "chi potrebbe esserci".

ROSTER_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROSTER_ROOT="$(cd "$ROSTER_LIB_DIR/../.." && pwd)"

roster_catalog_path() {
  if [ -n "${OFFICE_CATALOG_FILE:-}" ]; then
    echo "$OFFICE_CATALOG_FILE"
  else
    echo "$ROSTER_ROOT/catalog/roles.json"
  fi
}

roster_catalog_dir() {
  dirname "$(roster_catalog_path)"
}

roster_require_catalog() {
  local catalog
  catalog="$(roster_catalog_path)"
  if [ ! -f "$catalog" ]; then
    echo "Errore: catalogo dei ruoli non trovato in $catalog." >&2
    exit 2
  fi
  if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$catalog" >/dev/null 2>&1; then
    echo "Errore: $catalog non è un JSON valido." >&2
    exit 2
  fi
}

roster_slugs() {
  roster_require_catalog
  python3 - "$(roster_catalog_path)" <<'PY' 2>/dev/null
import json, sys
for r in json.load(open(sys.argv[1]))["roles"]:
    print(r["slug"])
PY
}

roster_coordinator_slugs() {
  roster_require_catalog
  python3 - "$(roster_catalog_path)" <<'PY' 2>/dev/null
import json, sys
for r in json.load(open(sys.argv[1]))["roles"]:
    if r.get("coordinator"):
        print(r["slug"])
PY
}

roster_role_get() {
  local slug="$1" field="$2"
  roster_require_catalog
  python3 - "$(roster_catalog_path)" "$slug" "$field" <<'PY' 2>/dev/null
import json, sys
path, slug, field = sys.argv[1], sys.argv[2], sys.argv[3]
for r in json.load(open(path))["roles"]:
    if r["slug"] == slug:
        v = r.get(field)
        if v is None:
            print("")
        elif isinstance(v, bool):
            print("true" if v else "false")
        elif isinstance(v, list):
            for item in v:
                print(item)
        else:
            print(v)
        sys.exit(0)
sys.exit(1)
PY
}

# Righe "Categoria · Label<TAB>slug", per alimentare gum filter.
roster_choices() {
  roster_require_catalog
  python3 - "$(roster_catalog_path)" <<'PY' 2>/dev/null
import json, sys
for r in json.load(open(sys.argv[1]))["roles"]:
    print(f"{r['category']} · {r['label']}\t{r['slug']}")
PY
}

roster_coordinator_choices() {
  roster_require_catalog
  python3 - "$(roster_catalog_path)" <<'PY' 2>/dev/null
import json, sys
for r in json.load(open(sys.argv[1]))["roles"]:
    if r.get("coordinator"):
        print(f"{r['label']}\t{r['slug']}")
PY
}

roster_id_from_name() {
  python3 - "$1" <<'PY'
import sys, unicodedata, re
name = unicodedata.normalize("NFKD", sys.argv[1])
name = "".join(c for c in name if not unicodedata.combining(c))
print(re.sub(r"[^a-z0-9]", "", name.lower()))
PY
}

# Palette per i nuovi assunti, in ordine di preferenza.
ROSTER_PALETTE="#f5b400 #4a90e2 #9b59b6 #e74c3c #1abc9c #2ecc71 #e67e22 #3498db #8e44ad #16a085 #d35400 #27ae60"

roster_next_color() {
  local team_json="$1"
  local used color
  used=$(python3 - "$team_json" <<'PY' 2>/dev/null
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
for m in data.get("team", []):
    print(m.get("color", ""))
PY
)
  for color in $ROSTER_PALETTE; do
    if ! echo "$used" | grep -qx -- "$color"; then
      echo "$color"
      return 0
    fi
  done

  # Palette esaurita: colore deterministico dalla dimensione del team.
  python3 - "$team_json" <<'PY'
import json, sys, colorsys
try:
    n = len(json.load(open(sys.argv[1])).get("team", []))
except Exception:
    n = 0
r, g, b = colorsys.hsv_to_rgb((n * 0.37) % 1.0, 0.65, 0.85)
print("#%02x%02x%02x" % (int(r * 255), int(g * 255), int(b * 255)))
PY
}

# Sostituisce i segnaposto di un template e scrive il risultato.
_roster_render() {
  local src="$1" dest="$2" name="$3" label="$4" id="$5"
  python3 - "$src" "$dest" "$name" "$label" "$id" <<'PY'
import sys
src, dest, name, label, agent_id = sys.argv[1:6]
text = open(src).read()
text = (text.replace("__AGENT_NAME__", name)
            .replace("__ROLE_LABEL__", label)
            .replace("__AGENT_ID__", agent_id))
open(dest, "w").write(text)
PY
}

# roster_generate_person <slug> <nome> <id> <dest_agents_dir> <team_json>
roster_generate_person() {
  local slug="$1" name="$2" id="$3" dest_dir="$4" team_json="$5"
  roster_require_catalog

  local label category mission log log_template tension
  label=$(roster_role_get "$slug" label) || return 1
  [ -n "$label" ] || return 1
  category=$(roster_role_get "$slug" category)
  mission=$(roster_role_get "$slug" mission)
  log=$(roster_role_get "$slug" log)
  log_template=$(roster_role_get "$slug" logTemplate)
  tension=$(roster_role_get "$slug" tension)

  local person_dir="$dest_dir/$id"
  mkdir -p "$person_dir"

  local catalog_dir
  catalog_dir="$(roster_catalog_dir)"

  # ── IDENTITY.md — interamente derivato dai dati, nessuna creatività ─────────
  {
    echo "# $name — Identity"
    echo ""
    echo "## Nome"
    echo "$name"
    echo ""
    echo "## Ruolo"
    echo "$label ($category)"
    echo ""
    echo "## Missione"
    echo "$mission"
    echo ""
    echo "## Cosa può fare"
    roster_role_get "$slug" can | while read -r line; do
      [ -n "$line" ] && echo "- $line"
    done
    echo ""
    echo "## Cosa non può fare"
    roster_role_get "$slug" cannot | while read -r line; do
      [ -n "$line" ] && echo "- $line"
    done
    echo ""
    echo "## Lavora con"
    roster_role_get "$slug" collaborates | while read -r other; do
      [ -n "$other" ] && echo "- $(roster_role_get "$other" label)"
    done
    echo ""
    echo "## Attrito dichiarato"
    echo "$tension"
    echo ""
    echo "I disaccordi sono parte del lavoro. Quando serve, spingi."
    echo ""
    echo "## Comunicazione"
    echo ""
    echo "Invia un messaggio:"
    echo '```'
    echo "./agents/msg.sh $id <destinatario> \"testo\""
    echo '```'
    echo ""
    echo "Chi c'è nel team: \`shared-context/TEAM.json\`"
    echo ""
    echo "Controlla l'inbox:"
    echo '```'
    echo "ls shared-context/inbox/$id/"
    echo '```'
    echo ""
    echo "Conferma ricezione:"
    echo '```'
    echo "./agents/ack.sh <msg-id> $id"
    echo '```'
    echo ""
    echo "**Regola:** ACK ogni messaggio ricevuto prima di rispondere."
    echo ""
    echo "## Stato"
    echo ""
    echo '```'
    echo "./agents/setstatus.sh $id WORKING \"<task corrente>\""
    echo "./agents/setstatus.sh $id IDLE"
    echo '```'
  } > "$person_dir/IDENTITY.md"

  # ── HEARTBEAT.md ────────────────────────────────────────────────────────────
  _roster_render "$catalog_dir/templates/heartbeat.md" "$person_dir/HEARTBEAT.md" "$name" "$label" "$id"

  # ── ROLE-BRIEF.md — la fonte per scrivere l'anima ───────────────────────────
  {
    echo "# $label — Role Brief"
    echo ""
    echo "Dati del ruolo dal catalogo. Servono a scrivere il SOUL.md quando manca."
    echo ""
    echo "- **Slug:** $slug"
    echo "- **Categoria:** $category"
    echo "- **Missione:** $mission"
    echo "- **Attrito:** $tension"
    echo ""
    echo "## Può"
    roster_role_get "$slug" can | while read -r line; do
      [ -n "$line" ] && echo "- $line"
    done
    echo ""
    echo "## Non può"
    roster_role_get "$slug" cannot | while read -r line; do
      [ -n "$line" ] && echo "- $line"
    done
    echo ""
    echo "## Lavora con"
    roster_role_get "$slug" collaborates | while read -r other; do
      [ -n "$other" ] && echo "- $(roster_role_get "$other" label)"
    done
  } > "$person_dir/ROLE-BRIEF.md"

  # ── Log di ruolo, se previsto ───────────────────────────────────────────────
  if [ -n "$log" ] && [ -n "$log_template" ]; then
    _roster_render "$catalog_dir/templates/$log_template.md" "$person_dir/$log" "$name" "$label" "$id"
  fi

  # ── SOUL.md, solo se il catalogo ne ha una scritta ─────────────────────────
  if [ -f "$catalog_dir/souls/$slug.md" ]; then
    _roster_render "$catalog_dir/souls/$slug.md" "$person_dir/SOUL.md" "$name" "$label" "$id"
  fi
}
