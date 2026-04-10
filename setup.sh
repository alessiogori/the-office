#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
# setup.sh — Configura il sistema multi-agente
# per un nuovo progetto
# ─────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   the-office — Setup multi-agente        ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "Questo script copia il sistema di agenti nel tuo progetto"
echo "e lo personalizza con le informazioni che fornisci."
echo ""

# ── Directory target ──────────────────────────
read -rp "📁 Directory di destinazione (es. /Users/me/Code/mio-progetto): " TARGET_DIR
if [[ -z "$TARGET_DIR" ]]; then
  echo "Errore: la directory di destinazione è obbligatoria."
  exit 1
fi

# Espandi ~ se presente
TARGET_DIR="${TARGET_DIR/#\~/$HOME}"

# ── Informazioni progetto ─────────────────────
echo ""
echo "── Informazioni progetto ──────────────────"
read -rp "Nome del progetto [my-project]: " PROJECT_NAME
PROJECT_NAME="${PROJECT_NAME:-my-project}"

read -rp "Descrizione breve (cosa fa il progetto): " PROJECT_DESC
PROJECT_DESC="${PROJECT_DESC:-Un progetto che usa il sistema multi-agente the-office.}"

read -rp "Tech stack (es. Laravel, Vue, MySQL): " TECH_STACK
TECH_STACK="${TECH_STACK:-Da definire}"

read -rp "Nome brand/azienda [${PROJECT_NAME}]: " BRAND_NAME
BRAND_NAME="${BRAND_NAME:-$PROJECT_NAME}"

# ── Nomi agenti ───────────────────────────────
echo ""
echo "── Nomi agenti (invio = mantieni default) ─"
read -rp "CEO [Alessio]: " CEO_NAME
CEO_NAME="${CEO_NAME:-Alessio}"

read -rp "Engineer [Stefano]: " ENGINEER_NAME
ENGINEER_NAME="${ENGINEER_NAME:-Stefano}"

read -rp "Product [Walter]: " PRODUCT_NAME
PRODUCT_NAME="${PRODUCT_NAME:-Walter}"

read -rp "Marketing [Veronica]: " MARKETING_NAME
MARKETING_NAME="${MARKETING_NAME:-Veronica}"

read -rp "UI/UX [Alessandra]: " UIUX_NAME
UIUX_NAME="${UIUX_NAME:-Alessandra}"

read -rp "Tester [Marwen]: " TESTER_NAME
TESTER_NAME="${TESTER_NAME:-Marwen}"

# ── Validazione directory target ──────────────
echo ""
if [[ -d "$TARGET_DIR" ]]; then
  if [[ -n "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]]; then
    echo "⚠️  La directory '$TARGET_DIR' esiste ed è non vuota."
    read -rp "   Continuare comunque? I file esistenti potrebbero essere sovrascritti [s/N]: " CONFIRM
    CONFIRM="${CONFIRM:-N}"
    if [[ "${CONFIRM,,}" != "s" ]]; then
      echo "Setup annullato."
      exit 0
    fi
  fi
else
  read -rp "La directory '$TARGET_DIR' non esiste. Crearla? [S/n]: " CREATE_DIR
  CREATE_DIR="${CREATE_DIR:-S}"
  if [[ "${CREATE_DIR,,}" == "s" ]]; then
    mkdir -p "$TARGET_DIR"
    echo "✓ Directory creata."
  else
    echo "Setup annullato."
    exit 0
  fi
fi

# ── Crea struttura directory ──────────────────
echo ""
echo "Creazione struttura directory..."

mkdir -p "$TARGET_DIR/agents/ceo"
mkdir -p "$TARGET_DIR/agents/engineer"
mkdir -p "$TARGET_DIR/agents/product"
mkdir -p "$TARGET_DIR/agents/marketing"
mkdir -p "$TARGET_DIR/agents/uiux"
mkdir -p "$TARGET_DIR/agents/tester"
mkdir -p "$TARGET_DIR/shared-context"
mkdir -p "$TARGET_DIR/examples/engineering"
mkdir -p "$TARGET_DIR/examples/marketing"
mkdir -p "$TARGET_DIR/examples/product"
mkdir -p "$TARGET_DIR/docs/sessions"

echo "✓ Struttura directory pronta."

# ── Genera shared-context/ ────────────────────
echo ""
echo "Generazione shared-context..."

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

echo "✓ shared-context/ generato."

# ── Genera file root ──────────────────────────
echo ""
echo "Generazione file di configurazione..."

cat > "$TARGET_DIR/CLAUDE.md" << EOF
# CLAUDE.md — Master Configuration

## Project Overview
**$PROJECT_NAME** — $PROJECT_DESC

Questo progetto usa un sistema multi-agente. Ogni agente ha un ruolo definito, una personalità e confini di accesso. Gli agenti coordinano attraverso file condivisi, non comunicazione diretta.

## Agent Roles

### CEO ($CEO_NAME)
- **Role:** Supervisione strategica, decisioni finali, allocazione risorse
- **Access:** Tutto. Nessuna restrizione.
- **Config:** agents/ceo/

### Engineer ($ENGINEER_NAME)
- **Role:** Costruire feature, fixare bug, scrivere test, deployare
- **Access:** Può leggere/scrivere codice, script, config. Non può toccare contenuti marketing o documenti di strategia prodotto.
- **Config:** agents/engineer/

### Product ($PRODUCT_NAME)
- **Role:** Strategia, roadmap, specifiche, ricerca utenti, prioritizzazione
- **Access:** Può leggere/scrivere docs di prodotto, spec, roadmap. Non può scrivere codice direttamente.
- **Config:** agents/product/

### Marketing ($MARKETING_NAME)
- **Role:** Creazione contenuti, brand voice, strategia di crescita, social media
- **Access:** Può leggere/scrivere solo nella cartella marketing/. Non può toccare codice o docs di prodotto.
- **Config:** agents/marketing/

### UI/UX Specialist ($UIUX_NAME)
- **Role:** Review qualità visiva e interazione, test headless Playwright, benchmarking standard di mercato
- **Access:** Può leggere tutto il codice frontend. Può eseguire Playwright. Può scrivere UI-REVIEW-LOG.md. Non può modificare il codice sorgente.
- **Config:** agents/uiux/

### Tester ($TESTER_NAME)
- **Role:** QA, testing, bug reporting, quality enforcement
- **Access:** Può leggere tutto il codice. Può scrivere report di test e bug log. Non può modificare il codice sorgente.
- **Config:** agents/tester/

## Tech Stack
$TECH_STACK

## Shared Context
Tutti gli agenti hanno accesso in lettura a shared-context/:
- THESIS.md — visione e valori del progetto
- ROADMAP.md — roadmap prodotto corrente
- BRAND-GUIDE.md — regole di voce, tono e stile

## Session Tracking
Ogni giorno genera un file di sessione: docs/sessions/YYYY-MM-DD-session.md
Ogni agente aggiorna la propria sezione. Un file da rivedere, non cinque.

## Rules
1. Gli agenti restano nel loro ruolo. Nessun attraversamento dei confini di accesso.
2. I disaccordi sono positivi. Il tester dovrebbe sfidare l'engineer. Il product lead dovrebbe spingere contro il CEO.
3. Ogni agente legge il suo SOUL.md e IDENTITY.md all'inizio di ogni sessione.
4. HEARTBEAT.md viene aggiornato al termine di ogni sessione.
5. In caso di dubbio, controlla shared-context/THESIS.md per allineamento.

## Slash Commands
- /startup — scegli il tuo ruolo e carica il contesto
- /engineer — passa all'Engineer
- /product — passa al Product
- /marketing — passa al Marketing
- /tester-agent — passa al Tester
- /session — aggiorna la tua sezione nel file di sessione condiviso
- /wrap-up — riepilogo fine giornata
EOF

cat > "$TARGET_DIR/AGENTS.md" << EOF
# AGENTS.md — Multi-Platform Agent Configuration
# Works with: Cursor, Copilot, Windsurf, Codex, Devin, Replit

## System Instructions

Sei parte di un team multi-agente. Prima di fare qualsiasi cosa, leggi i file di configurazione del tuo agente.

### Step 1: Identifica il tuo ruolo
Ti verrà assegnato uno di questi ruoli:
- **CEO** — Supervisione strategica, decisioni finali → Leggi agents/ceo/SOUL.md e agents/ceo/IDENTITY.md
- **Engineer** — Costruisce feature, fixa bug, deploya → Leggi agents/engineer/SOUL.md e agents/engineer/IDENTITY.md
- **Product** — Strategia, roadmap, specifiche → Leggi agents/product/SOUL.md e agents/product/IDENTITY.md
- **Marketing** — Contenuti, brand, crescita → Leggi agents/marketing/SOUL.md e agents/marketing/IDENTITY.md
- **UI/UX Specialist** — Review visiva, test Playwright, benchmarking → Leggi agents/uiux/SOUL.md e agents/uiux/IDENTITY.md
- **Tester** — QA, testing, qualità → Leggi agents/tester/SOUL.md e agents/tester/IDENTITY.md

### Step 2: Carica il contesto
- Leggi il tuo SOUL.md per capire come pensi
- Leggi il tuo IDENTITY.md per capire i tuoi confini di accesso
- Leggi il tuo HEARTBEAT.md per vedere su cosa stavi lavorando
- Leggi shared-context/THESIS.md per allineamento con la visione

### Step 3: Resta nel tuo ruolo
Ogni agente ha confini di accesso definiti in IDENTITY.md. Rispettali.

### Step 4: Aggiorna il tuo stato
Al termine di ogni sessione:
- Aggiorna il tuo HEARTBEAT.md con lo stato corrente
- Registra il tuo lavoro nel file specifico del tuo ruolo

## Quick Start Prompts

**Per iniziare come CEO:**
"Sei l'agente CEO. Leggi agents/ceo/SOUL.md e agents/ceo/IDENTITY.md. Controlla tutti i HEARTBEAT.md degli agenti e imposta le priorità di oggi."

**Per iniziare come Engineer:**
"Sei l'agente Engineer. Leggi agents/engineer/SOUL.md e agents/engineer/IDENTITY.md. Controlla BUILD-LOG.md per il contesto e inizia a costruire."

**Per iniziare come Product:**
"Sei l'agente Product. Leggi agents/product/SOUL.md e agents/product/IDENTITY.md. Rivedi BACKLOG.md e raffina la spec con priorità più alta."

**Per iniziare come Marketing:**
"Sei l'agente Marketing. Leggi agents/marketing/SOUL.md e agents/marketing/IDENTITY.md. Controlla CONTENT-CALENDAR.md e bozza il prossimo post."

**Per iniziare come UI/UX Specialist:**
"Sei $UIUX_NAME, la UI/UX Specialist. Leggi agents/uiux/SOUL.md e agents/uiux/IDENTITY.md. Controlla cosa ha shippato $ENGINEER_NAME e lancia Playwright headless su quelle pagine."

**Per iniziare come Tester:**
"Sei l'agente Tester. Leggi agents/tester/SOUL.md e agents/tester/IDENTITY.md. Controlla cosa ha deployato l'Engineer e inizia a testare."
EOF

sed \
  -e "s/Alessio/$CEO_NAME/g" \
  -e "s/Stefano/$ENGINEER_NAME/g" \
  -e "s/Walter/$PRODUCT_NAME/g" \
  -e "s/Veronica/$MARKETING_NAME/g" \
  -e "s/Alessandra/$UIUX_NAME/g" \
  -e "s/Marwen/$TESTER_NAME/g" \
  -e "s/5-agent system/6-agent system/g" \
  "$SCRIPT_DIR/GEMINI.md" > "$TARGET_DIR/GEMINI.md"

cp "$SCRIPT_DIR/.gitignore" "$TARGET_DIR/.gitignore"

echo "✓ CLAUDE.md, AGENTS.md, GEMINI.md, .gitignore generati."
