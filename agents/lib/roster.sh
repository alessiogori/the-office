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

# Come roster_id_from_name, ma tiene i trattini: per un nome di progetto
# "acme-shop" deve restare "acme-shop", non diventare "acmeshop".
roster_slugify() {
  python3 - "$1" <<'PY'
import sys, unicodedata, re
name = unicodedata.normalize("NFKD", sys.argv[1])
name = "".join(c for c in name if not unicodedata.combining(c))
slug = re.sub(r"[^a-z0-9]+", "-", name.lower())
print(slug.strip("-"))
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
# Usata solo da chi ha bisogno di rendere un singolo file: la generazione
# completa di una persona passa dal blocco python unico qui sotto.
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
#
# Un solo processo python: prima ne servivano quindici, e ognuno riapriva e
# riparsava il catalogo da 36 ruoli. Su un team di cinque persone erano
# settanta letture dello stesso file.
roster_generate_person() {
  local slug="$1" name="$2" id="$3" dest_dir="$4"
  roster_require_catalog

  python3 - "$(roster_catalog_path)" "$slug" "$name" "$id" "$dest_dir" <<'PY'
import os
import json
import sys

catalog_path, slug, name, agent_id, dest_dir = sys.argv[1:6]

roles = {r["slug"]: r for r in json.load(open(catalog_path))["roles"]}
role = roles.get(slug)
if role is None:
    sys.exit(1)

label = role["label"]
catalog_dir = os.path.dirname(catalog_path)
person_dir = os.path.join(dest_dir, agent_id)
os.makedirs(person_dir, exist_ok=True)


def render(src, dest):
    """Copia un template sostituendo i segnaposto."""
    text = open(src).read()
    text = (text.replace("__AGENT_NAME__", name)
                .replace("__ROLE_LABEL__", label)
                .replace("__AGENT_ID__", agent_id))
    open(dest, "w").write(text)


def bullets(items):
    return "\n".join(f"- {i}" for i in items)


collaborators = "\n".join(
    f"- {roles[c]['label']}" for c in role["collaborates"] if c in roles
)

# ── IDENTITY.md — interamente derivato dai dati, nessuna creatività ──────────
identity = f"""# {name} — Identity

## Nome
{name}

## Ruolo
{label} ({role['category']})

## Missione
{role['mission']}

## Cosa può fare
{bullets(role['can'])}

## Cosa non può fare
{bullets(role['cannot'])}

## Lavora con
{collaborators}

## Attrito dichiarato
{role['tension']}

I disaccordi sono parte del lavoro. Quando serve, spingi.

## Comunicazione

Invia un messaggio:
```
./agents/msg.sh {agent_id} <destinatario> "testo"
```

Chi c'è nel team: `shared-context/TEAM.json`

Controlla l'inbox:
```
ls shared-context/inbox/{agent_id}/
```

Conferma ricezione:
```
./agents/ack.sh <msg-id> {agent_id}
```

**Regola:** ACK ogni messaggio ricevuto prima di rispondere.

## Stato

```
./agents/setstatus.sh {agent_id} WORKING "<task corrente>"
./agents/setstatus.sh {agent_id} IDLE
```
"""
open(os.path.join(person_dir, "IDENTITY.md"), "w").write(identity)

# ── ROLE-BRIEF.md — la fonte per scrivere l'anima ────────────────────────────
brief = f"""# {label} — Role Brief

Dati del ruolo dal catalogo. Servono a scrivere il SOUL.md quando manca.

- **Slug:** {slug}
- **Categoria:** {role['category']}
- **Missione:** {role['mission']}
- **Attrito:** {role['tension']}

## Può
{bullets(role['can'])}

## Non può
{bullets(role['cannot'])}

## Lavora con
{collaborators}
"""
open(os.path.join(person_dir, "ROLE-BRIEF.md"), "w").write(brief)

# ── HEARTBEAT.md ─────────────────────────────────────────────────────────────
render(os.path.join(catalog_dir, "templates", "heartbeat.md"),
       os.path.join(person_dir, "HEARTBEAT.md"))

# ── Log di ruolo, se previsto ────────────────────────────────────────────────
log_name, log_template = role.get("log"), role.get("logTemplate")
if log_name and log_template:
    render(os.path.join(catalog_dir, "templates", f"{log_template}.md"),
           os.path.join(person_dir, log_name))

# ── SOUL.md, solo se il catalogo ne ha una scritta ───────────────────────────
soul = os.path.join(catalog_dir, "souls", f"{slug}.md")
if os.path.isfile(soul):
    render(soul, os.path.join(person_dir, "SOUL.md"))
PY
}
