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
WIZARD_TMP_CONFIG=""
TARGET_DIR=""
SAVE_CONFIG=""
EXPORT_ROOT="$SCRIPT_DIR/exports"
FORCE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --config)      CONFIG_FILE="${2:-}"; shift 2 ;;
    --target)      TARGET_DIR="${2:-}"; shift 2 ;;
    --export-dir)  EXPORT_ROOT="${2:-}"; shift 2 ;;
    --save-config) SAVE_CONFIG="${2:-}"; shift 2 ;;
    --force)       FORCE=1; shift ;;
    -h|--help)
      cat <<'USAGE'
Uso: ./setup.sh [opzioni]

Senza opzioni: wizard interattivo. Il team viene esportato come bundle
autonomo in exports/<nome-progetto>/, pronto da copiare in un progetto
esistente. Nessun progetto viene toccato.

  --config <file>       Legge il team da un JSON invece di chiederlo
  --target <dir>        Installa direttamente in <dir> invece di esportare
  --export-dir <dir>    Radice degli export (default: ./exports)
  --save-config <file>  Salva la configurazione usata
  --force               Consente di scrivere in una --target non vuota
USAGE
      exit 0 ;;
    *) echo "Opzione sconosciuta: $1" >&2; exit 2 ;;
  esac
done

dir_non_vuota() {
  [ -d "$1" ] && [ -n "$(ls -A "$1" 2>/dev/null)" ]
}

# Il config temporaneo del wizard contiene i dati del progetto: non va lasciato
# in giro in $TMPDIR.
cleanup_tmp() {
  [ -n "$WIZARD_TMP_CONFIG" ] && rm -f "$WIZARD_TMP_CONFIG"
  return 0
}
trap cleanup_tmp EXIT

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

# ── INTEGRAZIONE.md — come innestare il bundle in un progetto esistente ──────
generate_integration_guide() {
  local target="$1"
  local roster people
  roster="$(_team_roster_markdown "$target/shared-context/TEAM.json")"
  people=$(python3 -c "
import json,sys
t=json.load(open(sys.argv[1]))['team']
print(', '.join(f\"{m['name']} ({m['label']})\" for m in t))
" "$target/shared-context/TEAM.json")

  cat > "$target/INTEGRAZIONE.md" <<INTEGEOF
# Integrare questo team in $PROJECT_NAME

Bundle autonomo generato da the-office. Contiene tutto quello che serve: non
dipende dal repo che lo ha prodotto.

**Team:** $people

## Se il progetto è nuovo o non ha un CLAUDE.md

Copia tutto e hai finito:

\`\`\`bash
cp -R . /percorso/del/progetto/
cd /percorso/del/progetto
./agents/dashboard.sh
\`\`\`

## Se il progetto ha già un CLAUDE.md

Copia tutto **tranne** i tre file di configurazione, poi innesta la sezione
agenti in quello che hai già:

\`\`\`bash
PROG=/percorso/del/progetto

cp -R agents catalog shared-context "\$PROG/"
mkdir -p "\$PROG/docs/sessions"

# Appendi la sezione agenti al tuo CLAUDE.md invece di sostituirlo
sed -n '/^## Sistema multi-agente/,\$p' CLAUDE.md >> "\$PROG/CLAUDE.md"
\`\`\`

Fai lo stesso con \`AGENTS.md\` e \`GEMINI.md\` se il progetto li usa.

**Attenzione a \`shared-context/\`:** contiene \`THESIS.md\`, \`ROADMAP.md\` e
\`BRAND-GUIDE.md\` con contenuti segnaposto. Se il progetto ha già una sua
visione o una sua guida di stile, non sovrascriverli: copia solo
\`TEAM.json\`, \`inbox/\` e \`queues/\`.

\`\`\`bash
cp shared-context/TEAM.json "\$PROG/shared-context/"
cp -R shared-context/inbox shared-context/queues "\$PROG/shared-context/"
\`\`\`

## Cosa stai copiando

| Percorso | Cosa contiene |
|----------|---------------|
| \`agents/<persona>/\` | Una cartella per persona: identità, heartbeat, brief, log |
| \`agents/lib/\` | Le librerie che leggono il team a runtime |
| \`agents/*.sh\` | msg, ack, setstatus, qtask, hire, dashboard, launch, iterm |
| \`agents/_authoring/\` | Le regole per scrivere un SOUL.md |
| \`catalog/roles.json\` | Le figure disponibili, per assumere in futuro |
| \`shared-context/TEAM.json\` | Chi c'è nel team: la sorgente di verità |
| \`CLAUDE.md\`, \`AGENTS.md\`, \`GEMINI.md\` | Istruzioni per i vari AI tool |

## Il team

$roster

## Dopo l'integrazione

\`\`\`bash
./agents/dashboard.sh      # verifica che il team sia visto
./agents/iterm.sh all      # una finestra per persona (macOS + iTerm2)
./agents/hire.sh           # aggiungi qualcuno
\`\`\`

Al primo avvio, ogni agente il cui \`SOUL.md\` non esiste se lo scrive da solo,
leggendo il proprio \`ROLE-BRIEF.md\` e il contesto del progetto. È voluto:
l'anima nasce calata su **questo** progetto invece che generica.

## Requisiti

\`bash\` 3.2+ e \`python3\`. Niente altro. \`iTerm2\` serve solo per la consegna
dei messaggi in finestra; senza, i messaggi restano comunque su log e inbox.

## Questo file

Puoi cancellarlo dopo l'integrazione: serve solo al trasporto.
INTEGEOF
}

# ── Wizard interattivo ────────────────────────────────────────────────────────
# Raccoglie le scelte con gum e le scrive in un file di config temporaneo,
# assegnandolo a CONFIG_FILE: da lì in poi il percorso è identico a --config.
wizard_collect_interactive() {
  tui_require_gum

  gum style --border rounded --padding "1 3" --margin "1 0" \
    "the-office — composizione del team"

  local name desc stack brand size slug
  while true; do
    name=$(gum input --value "my-project" --header "Nome del progetto")
    [ -n "$name" ] || { echo "Nome obbligatorio." >&2; exit 2; }
    slug=$(roster_slugify "$name")
    if [ -z "$slug" ]; then
      gum style --foreground 196 "Da '$name' non ricavo un nome di cartella. Usa lettere o numeri."
      continue
    fi
    if dir_non_vuota "$EXPORT_ROOT/$slug"; then
      gum style --foreground 196 "Esiste già un export in $EXPORT_ROOT/$slug. Scegli un altro nome o rimuovilo."
      continue
    fi
    break
  done
  desc=$(gum input --placeholder "Cosa fa questo progetto" --header "Descrizione breve")
  stack=$(gum input --placeholder "Laravel, Vue, MySQL" --header "Tech stack")
  brand=$(gum input --value "$name" --header "Nome brand")

  # Quante persone. Il tetto di 12 non è arbitrario: sono 12 terminali aperti.
  while true; do
    size=$(gum input --value "4" --header "Quante persone servono nel team? (1-12)")
    case "$size" in
      ''|*[!0-9]*) gum style --foreground 196 "Inserisci un numero."; continue ;;
    esac
    if [ "$size" -ge 1 ] && [ "$size" -le 12 ]; then break; fi
    gum style --foreground 196 "Il team deve avere tra 1 e 12 persone."
  done

  CONFIG_FILE="$(mktemp)"
  WIZARD_TMP_CONFIG="$CONFIG_FILE"
  local roles_file names_file
  roles_file="$(mktemp)"
  names_file="$(mktemp)"

  # Persona 1: sempre un ruolo di coordinamento. Il vincolo è un passo del
  # flusso, non una regola nascosta nella validazione.
  local slug person_name suggested i new_id existing existing_id dup
  slug=$(tui_pick_coordinator) || { echo "Selezione annullata." >&2; exit 2; }
  suggested=$(tui_suggest_name 0)
  person_name=$(tui_ask_name "$suggested")
  [ -n "$person_name" ] || { echo "Nome obbligatorio." >&2; exit 2; }
  while [ -z "$(roster_id_from_name "$person_name")" ]; do
    gum style --foreground 196 "Da '$person_name' non ricavo un id. Usa lettere o numeri."
    person_name=$(tui_ask_name "$suggested")
    [ -n "$person_name" ] || { echo "Nome obbligatorio." >&2; exit 2; }
  done
  echo "$slug"        >> "$roles_file"
  echo "$person_name" >> "$names_file"

  # Persone da 2 a N: uno slot alla volta, così i duplicati di ruolo
  # funzionano senza casi speciali.
  i=1
  while [ "$i" -lt "$size" ]; do
    slug=$(tui_pick_role "Persona $((i + 1)) di $size — che ruolo ha?") \
      || { echo "Selezione annullata." >&2; exit 2; }
    suggested=$(tui_suggest_name "$i")
    person_name=$(tui_ask_name "$suggested")
    [ -n "$person_name" ] || { echo "Nome obbligatorio." >&2; exit 2; }

    new_id=$(roster_id_from_name "$person_name")
    if [ -z "$new_id" ]; then
      gum style --foreground 196 "Da '$person_name' non ricavo un id. Usa lettere o numeri."
      continue
    fi
    dup=0
    while read -r existing; do
      existing_id=$(roster_id_from_name "$existing")
      [ "$existing_id" = "$new_id" ] && dup=1
    done < "$names_file"
    if [ "$dup" -eq 1 ]; then
      gum style --foreground 196 "Esiste già una persona con id '$new_id'. Scegli un altro nome."
      continue
    fi

    echo "$slug"        >> "$roles_file"
    echo "$person_name" >> "$names_file"
    i=$((i + 1))
  done

  python3 - "$CONFIG_FILE" "$name" "$desc" "$stack" "$brand" "$roles_file" "$names_file" <<'PY'
import json, sys
out, name, desc, stack, brand, roles_f, names_f = sys.argv[1:8]
roles = [l.strip() for l in open(roles_f) if l.strip()]
names = [l.strip() for l in open(names_f) if l.strip()]
json.dump({
    "project": {"name": name, "description": desc, "stack": stack, "brand": brand},
    "team": [{"role": r, "name": n} for r, n in zip(roles, names)],
}, open(out, "w"), indent=2, ensure_ascii=False)
PY

  rm -f "$roles_file" "$names_file"

  # Riepilogo e conferma: nulla viene scritto su disco prima di questo sì.
  echo ""
  gum style --border rounded --padding "0 2" "Team"
  python3 - "$CONFIG_FILE" <<'PY'
import json, sys
for m in json.load(open(sys.argv[1]))["team"]:
    print(f"  {m['name']:<14} {m['role']}")
PY
  echo ""
  gum confirm "Esporto il bundle in $EXPORT_ROOT/$slug?" || { echo "Setup annullato."; exit 0; }

  validate_config "$CONFIG_FILE"
}

# ── Raccolta della configurazione ─────────────────────────────────────────────
if [ -n "$CONFIG_FILE" ]; then
  [ -f "$CONFIG_FILE" ] || { echo "Errore: $CONFIG_FILE non trovato." >&2; exit 2; }
  validate_config "$CONFIG_FILE"
else
  wizard_collect_interactive
fi

PROJECT_NAME=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['project']['name'])" "$CONFIG_FILE")
PROJECT_DESC=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['project']['description'])" "$CONFIG_FILE")
TECH_STACK=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['project']['stack'])" "$CONFIG_FILE")
BRAND_NAME=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['project']['brand'])" "$CONFIG_FILE")

# ── Destinazione: export (default) o installazione diretta ────────────────────
if [ -z "$TARGET_DIR" ]; then
  TARGET_DIR=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['project'].get('target',''))" "$CONFIG_FILE")
fi

if [ -n "$TARGET_DIR" ]; then
  # Installazione diretta: la destinazione può essere un progetto vivo.
  EXPORT_MODE=""
  TARGET_DIR="${TARGET_DIR/#\~/$HOME}"

  if dir_non_vuota "$TARGET_DIR"; then
    echo "" >&2
    echo "Attenzione: $TARGET_DIR esiste ed è non vuota." >&2
    echo "Il setup sovrascrive CLAUDE.md, AGENTS.md, GEMINI.md, .gitignore e i file" >&2
    echo "di shared-context/ senza fonderli con quelli esistenti." >&2

    if [ -n "$FORCE" ]; then
      echo "Procedo comunque (--force)." >&2
    elif [ -t 0 ] && [ -z "$CONFIG_FILE" ]; then
      printf "Continuare? [s/N]: " >&2
      read -r conferma
      if [ "$(echo "$conferma" | tr '[:upper:]' '[:lower:]')" != "s" ]; then
        echo "Setup annullato." >&2
        exit 0
      fi
    else
      echo "" >&2
      echo "Rilancia con --force se è quello che vuoi, oppure ometti --target per" >&2
      echo "generare un bundle in exports/ e innestarlo a mano." >&2
      exit 2
    fi
  fi
else
  # Export: destinazione sempre nuova, nessun progetto esistente coinvolto.
  EXPORT_MODE=1
  PROJECT_SLUG=$(roster_slugify "$PROJECT_NAME")
  [ -n "$PROJECT_SLUG" ] || { echo "Errore: il nome progetto '$PROJECT_NAME' non produce uno slug valido." >&2; exit 2; }
  TARGET_DIR="$EXPORT_ROOT/$PROJECT_SLUG"

  if dir_non_vuota "$TARGET_DIR"; then
    echo "Errore: l'export '$TARGET_DIR' esiste già e non è vuoto." >&2
    echo "Un bundle non viene sovrascritto: rimuovilo, oppure usa un nome progetto diverso." >&2
    exit 2
  fi
fi

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
if [ -s "$TARGET_DIR/shared-context/TEAM.json" ] && [ -z "$FORCE" ]; then
  echo "Errore: $TARGET_DIR/shared-context/TEAM.json esiste già." >&2
  echo "Rigenerare azzererebbe il team, lasciando orfane le cartelle degli agenti." >&2
  echo "Per aggiungere una persona usa ./agents/hire.sh; per rifare tutto usa --force." >&2
  exit 2
fi
echo '{"version":1,"team":[]}' > "$TARGET_DIR/shared-context/TEAM.json"

COUNT=$(python3 -c "import json,sys; print(len(json.load(open(sys.argv[1]))['team']))" "$CONFIG_FILE")
i=0
while [ "$i" -lt "$COUNT" ]; do
  SLUG=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['team'][$i]['role'])" "$CONFIG_FILE")
  NAME=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['team'][$i]['name'])" "$CONFIG_FILE")
  ID=$(roster_id_from_name "$NAME")
  COLOR=$(roster_next_color "$TARGET_DIR/shared-context/TEAM.json")

  roster_generate_person "$SLUG" "$NAME" "$ID" "$TARGET_DIR/agents"

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
rm -rf "$TARGET_DIR/catalog/templates"
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

if [ -n "$EXPORT_MODE" ]; then
  generate_integration_guide "$TARGET_DIR"
  echo "✓ INTEGRAZIONE.md scritto."
  echo ""
  echo "  Bundle pronto in $TARGET_DIR"
  echo ""
  echo "  Per innestarlo in un progetto esistente:"
  echo "    cat $TARGET_DIR/INTEGRAZIONE.md"
  echo ""
  echo "  In breve, se il progetto non ha già un CLAUDE.md:"
  echo "    cp -R $TARGET_DIR/. /percorso/del/progetto/"
  echo ""
else
  echo ""
  echo "  Progetto generato in $TARGET_DIR"
  echo ""
  echo "  Prossimi passi:"
  echo "    cd $TARGET_DIR"
  echo "    ./agents/dashboard.sh          # chi c'è nel team"
  echo "    ./agents/iterm.sh all          # apri un terminale per ciascuno"
  echo ""
fi
