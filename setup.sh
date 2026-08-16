#!/usr/bin/env bash
# setup.sh — Compone il team di un progetto e genera il sistema multi-agente.
#
# Uso:
#   ./setup.sh                                   wizard interattivo (richiede gum)
#   ./setup.sh --config <file> --target <dir>    non interattivo, riproducibile
#   ./setup.sh --save-config <file>              esporta le scelte fatte
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/agents/lib/roster.sh"
source "$SCRIPT_DIR/agents/lib/tui.sh"

CONFIG_FILE=""
TARGET_DIR=""
SAVE_CONFIG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --config)      CONFIG_FILE="${2:-}"; shift 2 ;;
    --target)      TARGET_DIR="${2:-}"; shift 2 ;;
    --save-config) SAVE_CONFIG="${2:-}"; shift 2 ;;
    -h|--help)
      echo "Uso: ./setup.sh [--config <file>] [--target <dir>] [--save-config <file>]"
      exit 0 ;;
    *) echo "Opzione sconosciuta: $1" >&2; exit 2 ;;
  esac
done

# ── Validazione della configurazione ──────────────────────────────────────────
# Team non vuoto, prima persona coordinatrice, ruoli esistenti, id univoci.
validate_config() {
  local config="$1"
  python3 - "$config" "$(roster_catalog_path)" <<'PY'
import json, sys, unicodedata, re

config_path, catalog_path = sys.argv[1], sys.argv[2]

try:
    config = json.load(open(config_path))
except Exception as e:
    print(f"Errore: config non valida ({e}).", file=sys.stderr)
    sys.exit(2)

roles = {r["slug"]: r for r in json.load(open(catalog_path))["roles"]}
team = config.get("team", [])

if not team:
    print("Errore: il team è vuoto. Serve almeno una persona.", file=sys.stderr)
    sys.exit(2)

def to_id(name):
    n = unicodedata.normalize("NFKD", name)
    n = "".join(c for c in n if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]", "", n.lower())

for m in team:
    if m.get("role") not in roles:
        print(f"Errore: ruolo '{m.get('role')}' non presente nel catalogo.", file=sys.stderr)
        sys.exit(2)
    if not m.get("name"):
        print("Errore: ogni persona deve avere un nome.", file=sys.stderr)
        sys.exit(2)

if not roles[team[0]["role"]].get("coordinator"):
    print("Errore: la prima persona deve avere un ruolo di coordinamento.", file=sys.stderr)
    print("Ruoli di coordinamento validi: "
          + ", ".join(s for s, r in roles.items() if r.get("coordinator")), file=sys.stderr)
    sys.exit(2)

seen = {}
for m in team:
    i = to_id(m["name"])
    if not i:
        print(f"Errore: il nome '{m['name']}' non produce un id valido.", file=sys.stderr)
        sys.exit(2)
    if i in seen:
        print(f"Errore: due persone producono lo stesso id '{i}' "
              f"({seen[i]} e {m['name']}).", file=sys.stderr)
        sys.exit(2)
    seen[i] = m["name"]
PY
}

# ── Elenco del team in markdown, una voce per persona ────────────────────────
_team_roster_markdown() {
  local team_json="$1"
  python3 - "$team_json" "$(roster_catalog_path)" <<'PY'
import json, sys
team = json.load(open(sys.argv[1]))["team"]
roles = {r["slug"]: r for r in json.load(open(sys.argv[2]))["roles"]}
for m in team:
    r = roles[m["role"]]
    print(f"### {m['name']} — {m['label']}")
    print(f"- **Missione:** {r['mission']}")
    print(f"- **Può:** {r['can'][0]}")
    print(f"- **Non può:** {r['cannot'][0]}")
    print(f"- **Attrito:** {r['tension']}")
    print(f"- **Config:** {m['folder']}/")
    print()
PY
}

# ── CLAUDE.md, AGENTS.md, GEMINI.md, generati dal team reale ─────────────────
generate_agent_docs() {
  local target="$1"
  local roster
  roster="$(_team_roster_markdown "$target/shared-context/TEAM.json")"

  cat > "$target/CLAUDE.md" <<CLAUDEEOF
# CLAUDE.md — $PROJECT_NAME

## Progetto
$PROJECT_DESC

**Stack:** $TECH_STACK

## Sistema multi-agente

Questo progetto usa un sistema multi-agente. Il team è descritto in
\`shared-context/TEAM.json\`: quello è l'elenco autorevole, questa sezione ne è
il riassunto leggibile. Gli script validano gli agenti contro il manifest.

$roster

## Contesto condiviso
Letto da tutti: \`shared-context/THESIS.md\`, \`ROADMAP.md\`, \`BRAND-GUIDE.md\`.

## Regole
1. Ogni agente resta nel suo dominio, definito nel suo \`IDENTITY.md\`.
2. I disaccordi sono un bene: ogni ruolo ha un attrito dichiarato ed è tenuto a usarlo.
3. Ogni agente legge SOUL.md e IDENTITY.md all'inizio della sessione.
   Se SOUL.md non esiste, lo scrive seguendo \`agents/_authoring/SOUL-AUTHORING.md\`.
4. HEARTBEAT.md va aggiornato a fine sessione.
5. In caso di dubbio, \`shared-context/THESIS.md\`.

## Comandi
\`\`\`bash
./agents/launch.sh <agente>       # avvia un agente
./agents/iterm.sh <agente|all>    # finestre iTerm2 dedicate
./agents/setstatus.sh <agente> <WORKING|IDLE|STANDBY> ["task"]
./agents/msg.sh <da> <a> "<testo>"
./agents/ack.sh <msg-id> <agente>
./agents/qtask.sh <add|done|list> <agente> [...]
./agents/dashboard.sh             # stato del team
./agents/hire.sh                  # aggiungi una persona
\`\`\`

## Sessioni
Un file al giorno: \`docs/sessions/YYYY-MM-DD-session.md\`. Ogni agente aggiorna
solo la propria sezione.
CLAUDEEOF

  cat > "$target/AGENTS.md" <<AGENTSEOF
# AGENTS.md — $PROJECT_NAME
# Cursor, Copilot, Windsurf, Codex, Devin, Replit

## Istruzioni

Fai parte di un team multi-agente. Prima di qualsiasi cosa, carica il tuo ruolo.

### 1. Identifica il ruolo
Il team è in \`shared-context/TEAM.json\`. Trova la tua voce e usa il campo
\`folder\` per sapere dove stanno i tuoi file.

$roster

### 2. Carica il contesto
- \`<folder>/SOUL.md\` — come pensi. Se manca, scrivilo seguendo
  \`agents/_authoring/SOUL-AUTHORING.md\` e \`<folder>/ROLE-BRIEF.md\`.
- \`<folder>/IDENTITY.md\` — i tuoi confini di accesso, vincolanti
- \`<folder>/HEARTBEAT.md\` — su cosa stavi lavorando
- \`shared-context/THESIS.md\` — la visione

### 3. Resta nel tuo dominio
I confini sono in IDENTITY.md. Rispettali.

### 4. Chiudi la sessione
Aggiorna HEARTBEAT.md e il tuo log di ruolo, se ne hai uno.
AGENTSEOF

  cat > "$target/GEMINI.md" <<GEMINIEOF
# GEMINI.md — $PROJECT_NAME

## Istruzioni

Fai parte di un team multi-agente. Il team è descritto in
\`shared-context/TEAM.json\`; ogni persona ha una cartella indicata dal campo
\`folder\`, con SOUL.md (come pensa), IDENTITY.md (cosa può toccare) e
HEARTBEAT.md (a che punto è).

$roster

## Avvio
1. Trova la tua voce in \`shared-context/TEAM.json\`
2. Leggi SOUL.md e IDENTITY.md nella tua cartella. Se SOUL.md manca, scrivilo
   seguendo \`agents/_authoring/SOUL-AUTHORING.md\`
3. Leggi \`shared-context/THESIS.md\`
4. Resta nei confini di IDENTITY.md
5. A fine sessione aggiorna HEARTBEAT.md
GEMINIEOF
}

# ── Raccolta della configurazione ─────────────────────────────────────────────
if [ -n "$CONFIG_FILE" ]; then
  [ -f "$CONFIG_FILE" ] || { echo "Errore: $CONFIG_FILE non trovato." >&2; exit 2; }
  validate_config "$CONFIG_FILE"
else
  wizard_collect_interactive
fi

if [ -z "$TARGET_DIR" ]; then
  TARGET_DIR=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['project'].get('target',''))" "$CONFIG_FILE")
fi
[ -n "$TARGET_DIR" ] || { echo "Errore: directory di destinazione non specificata (--target)." >&2; exit 2; }
TARGET_DIR="${TARGET_DIR/#\~/$HOME}"

PROJECT_NAME=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['project']['name'])" "$CONFIG_FILE")
PROJECT_DESC=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['project']['description'])" "$CONFIG_FILE")
TECH_STACK=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['project']['stack'])" "$CONFIG_FILE")
BRAND_NAME=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['project']['brand'])" "$CONFIG_FILE")

# ── Struttura ─────────────────────────────────────────────────────────────────
mkdir -p "$TARGET_DIR/agents/lib" "$TARGET_DIR/agents/_authoring" \
         "$TARGET_DIR/shared-context/inbox" "$TARGET_DIR/shared-context/queues" \
         "$TARGET_DIR/catalog" "$TARGET_DIR/docs/sessions"

cat > "$TARGET_DIR/shared-context/THESIS.md" << EOF
# Thesis — What We Believe

## Core Belief
$PROJECT_DESC

## Who We Serve
Le persone e i team che usano $PROJECT_NAME ogni giorno.

## How We Win
1. Costruire in modo iterativo. Shippa, impara, migliora.
2. Qualità e velocità non si escludono. Scegli entrambe.
3. Ogni feature deve risolvere un problema reale per un utente reale.
4. Tieni il sistema semplice. Complessità non necessaria è debito tecnico.

## What We Won't Do
- Costruire feature che nessuno ha chiesto
- Ignorare il feedback degli utenti
- Shippa senza test sui percorsi critici
- Lasciare che la complessità tecnica blocchi il progresso

## The Test
Prima di costruire qualcosa, chiedi: "Questo risolve un problema reale?"
Se la risposta non è un sì immediato, non costruirlo.
EOF

cat > "$TARGET_DIR/shared-context/ROADMAP.md" << EOF
# Roadmap

## Now (This Sprint)
- [Prima priorità — da definire]

## Next (Next 2 Weeks)
- [Prossima feature — da definire]

## Later (This Quarter)
- [Idea futura — da definire]

## Done
- Setup sistema multi-agente ($(date +%Y-%m-%d))

## Tech Stack
$TECH_STACK

## Rules
- Max 3 item in "Now" in ogni momento
- Nulla si sposta in "Now" senza una spec da Product
- Nulla va in produzione senza sign-off del Tester
- Il CEO può cambiare le priorità ma deve documentare il perché
EOF

cat > "$TARGET_DIR/shared-context/BRAND-GUIDE.md" << EOF
# Brand Guide — How We Sound

## Brand
$BRAND_NAME

## Voice
- Human first. Suoniamo come persone, non come aziende.
- Diretto. Dì le cose in meno parole.
- Onesto. Se qualcosa è difficile, dillo. Se non sappiamo, lo diciamo.
- Informale ma non sciatto.

## Writing Rules
- Frasi brevi. Anche incomplete.
- Niente em dash. Segnalano contenuto generato da AI.
- Niente elenchi nei post social.
- Max 2 emoji per post.
- Chiudi con una domanda genuina.

## What We Never Say
- "Game-changer"
- "Potenzia il tuo workflow"
- Qualsiasi cosa che sembri generata dagli stessi tool che usiamo

## What We Always Do
- Inizia col problema, non con il prodotto
- Usa numeri specifici invece di affermazioni vaghe
- Racconta storie dalla nostra esperienza
- Ammetti quando non abbiamo la risposta
EOF


# ── Persone e manifest ────────────────────────────────────────────────────────
echo '{"version":1,"team":[]}' > "$TARGET_DIR/shared-context/TEAM.json"

COUNT=$(python3 -c "import json,sys; print(len(json.load(open(sys.argv[1]))['team']))" "$CONFIG_FILE")
i=0
while [ "$i" -lt "$COUNT" ]; do
  SLUG=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['team'][$i]['role'])" "$CONFIG_FILE")
  NAME=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['team'][$i]['name'])" "$CONFIG_FILE")
  ID=$(roster_id_from_name "$NAME")
  COLOR=$(roster_next_color "$TARGET_DIR/shared-context/TEAM.json")

  roster_generate_person "$SLUG" "$NAME" "$ID" "$TARGET_DIR/agents" "$TARGET_DIR/shared-context/TEAM.json"

  LABEL=$(roster_role_get "$SLUG" label)
  LOG=$(roster_role_get "$SLUG" log)
  COORD=$(roster_role_get "$SLUG" coordinator)

  python3 - "$TARGET_DIR/shared-context/TEAM.json" "$ID" "$NAME" "$SLUG" "$LABEL" "$LOG" "$COLOR" "$COORD" <<'PY'
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

  mkdir -p "$TARGET_DIR/shared-context/inbox/$ID"
  echo "[]" > "$TARGET_DIR/shared-context/queues/$ID.json"

  i=$((i + 1))
done

echo "✓ ${COUNT} persone create."

# ── Script, librerie, catalogo ────────────────────────────────────────────────
for s in msg.sh ack.sh setstatus.sh qtask.sh with-status.sh launch.sh iterm.sh \
         dashboard.sh live-dashboard.sh hire.sh; do
  cp "$SCRIPT_DIR/agents/$s" "$TARGET_DIR/agents/$s"
  chmod +x "$TARGET_DIR/agents/$s"
done

cp "$SCRIPT_DIR/agents/lib/team.sh"   "$TARGET_DIR/agents/lib/team.sh"
cp "$SCRIPT_DIR/agents/lib/roster.sh" "$TARGET_DIR/agents/lib/roster.sh"
cp "$SCRIPT_DIR/agents/lib/tui.sh"    "$TARGET_DIR/agents/lib/tui.sh"
cp -R "$SCRIPT_DIR/catalog/templates" "$TARGET_DIR/catalog/templates"
cp "$SCRIPT_DIR/catalog/roles.json"   "$TARGET_DIR/catalog/roles.json"
cp "$SCRIPT_DIR/catalog/SOUL-AUTHORING.md" "$TARGET_DIR/agents/_authoring/SOUL-AUTHORING.md"

# catalog/souls/ NON viene copiato: le anime dei ruoli scelti sono già state
# scritte nelle cartelle persona da roster_generate_person.

if [ -f "$SCRIPT_DIR/.gitignore" ]; then
  cp "$SCRIPT_DIR/.gitignore" "$TARGET_DIR/.gitignore"
fi

echo "✓ Script, librerie e catalogo copiati."

# ── Documenti di configurazione ───────────────────────────────────────────────
generate_agent_docs "$TARGET_DIR"
echo "✓ CLAUDE.md, AGENTS.md e GEMINI.md generati."

if [ -n "$SAVE_CONFIG" ]; then
  cp "$CONFIG_FILE" "$SAVE_CONFIG"
  echo "✓ Configurazione salvata in $SAVE_CONFIG"
fi

echo ""
echo "  Progetto generato in $TARGET_DIR"
echo ""
echo "  Prossimi passi:"
echo "    cd $TARGET_DIR"
echo "    ./agents/dashboard.sh          # chi c'è nel team"
echo "    ./agents/iterm.sh all          # apri un terminale per ciascuno"
echo ""
