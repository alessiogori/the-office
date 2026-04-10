# Setup Script Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Creare `setup.sh` — uno script bash interattivo che raccoglie le informazioni di un nuovo progetto, genera i file personalizzati e copia tutto nella directory target.

**Architecture:** Script bash puro in `setup.sh` nella root del progetto. Raccoglie input via `read`, genera i file `shared-context/` con heredoc e variabili interpolate, copia e trasforma i file degli agenti via `sed` per sostituire i nomi. Nessuna dipendenza esterna.

**Tech Stack:** bash, sed, cp, mkdir

---

### Task 1: Scheletro dello script + raccolta input

**Files:**
- Create: `setup.sh`

- [ ] **Step 1: Crea il file con shebang e messaggio di benvenuto**

```bash
cat > setup.sh << 'SCRIPT'
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
SCRIPT
chmod +x setup.sh
```

- [ ] **Step 2: Aggiungi raccolta input — directory e progetto**

Apri `setup.sh` e aggiungi dopo il blocco di echo:

```bash
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
```

- [ ] **Step 3: Aggiungi raccolta nomi agenti**

```bash
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
```

- [ ] **Step 4: Verifica che lo script sia eseguibile e non dia errori di sintassi**

```bash
bash -n setup.sh
```

Expected: nessun output (nessun errore di sintassi)

- [ ] **Step 5: Commit**

```bash
git add setup.sh
git commit -m "feat: setup.sh — scheletro e raccolta input"
```

---

### Task 2: Validazione e creazione directory target

**Files:**
- Modify: `setup.sh`

- [ ] **Step 1: Aggiungi la logica di validazione dopo la raccolta degli input**

```bash
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
```

- [ ] **Step 2: Aggiungi la creazione delle sottodirectory**

```bash
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
```

- [ ] **Step 3: Verifica sintassi**

```bash
bash -n setup.sh
```

Expected: nessun output

- [ ] **Step 4: Commit**

```bash
git add setup.sh
git commit -m "feat: setup.sh — validazione e creazione directory target"
```

---

### Task 3: Genera shared-context/ (THESIS, ROADMAP, BRAND-GUIDE)

**Files:**
- Modify: `setup.sh`

- [ ] **Step 1: Genera THESIS.md**

```bash
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
```

- [ ] **Step 2: Genera ROADMAP.md**

```bash
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
```

- [ ] **Step 3: Genera BRAND-GUIDE.md**

```bash
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
```

- [ ] **Step 4: Verifica sintassi**

```bash
bash -n setup.sh
```

Expected: nessun output

- [ ] **Step 5: Commit**

```bash
git add setup.sh
git commit -m "feat: setup.sh — genera shared-context con variabili interpolate"
```

---

### Task 4: Genera CLAUDE.md, AGENTS.md, GEMINI.md

**Files:**
- Modify: `setup.sh`

- [ ] **Step 1: Genera CLAUDE.md**

```bash
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
```

- [ ] **Step 2: Genera AGENTS.md**

```bash
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
```

- [ ] **Step 3: Genera GEMINI.md**

```bash
sed \
  -e "s/Alessio/$CEO_NAME/g" \
  -e "s/Stefano/$ENGINEER_NAME/g" \
  -e "s/Walter/$PRODUCT_NAME/g" \
  -e "s/Veronica/$MARKETING_NAME/g" \
  -e "s/Alessandra/$UIUX_NAME/g" \
  -e "s/Marwen/$TESTER_NAME/g" \
  -e "s/5-agent system/6-agent system/g" \
  "$SCRIPT_DIR/GEMINI.md" > "$TARGET_DIR/GEMINI.md"
```

- [ ] **Step 4: Copia .gitignore**

```bash
cp "$SCRIPT_DIR/.gitignore" "$TARGET_DIR/.gitignore"
```

- [ ] **Step 5: Verifica sintassi**

```bash
bash -n setup.sh
```

Expected: nessun output

- [ ] **Step 6: Commit**

```bash
git add setup.sh
git commit -m "feat: setup.sh — genera CLAUDE.md, AGENTS.md, GEMINI.md"
```

---

### Task 5: Genera agents/msg.sh con nomi aggiornati

**Files:**
- Modify: `setup.sh`

- [ ] **Step 1: Genera msg.sh dinamicamente**

Il file viene generato fresh (non copiato) perché i nomi lowercase nel `case` statement devono corrispondere ai nuovi nomi scelti.

```bash
CEO_LOWER=$(echo "$CEO_NAME" | tr '[:upper:]' '[:lower:]')
ENGINEER_LOWER=$(echo "$ENGINEER_NAME" | tr '[:upper:]' '[:lower:]')
PRODUCT_LOWER=$(echo "$PRODUCT_NAME" | tr '[:upper:]' '[:lower:]')
MARKETING_LOWER=$(echo "$MARKETING_NAME" | tr '[:upper:]' '[:lower:]')
UIUX_LOWER=$(echo "$UIUX_NAME" | tr '[:upper:]' '[:lower:]')
TESTER_LOWER=$(echo "$TESTER_NAME" | tr '[:upper:]' '[:lower:]')

cat > "$TARGET_DIR/agents/msg.sh" << EOF
#!/bin/bash
# msg.sh — Invia un messaggio direttamente nel prompt Claude Code di un altro agente
# Uso: ./agents/msg.sh <destinatario> "<messaggio>"

RECIPIENT=\$(echo "\$1" | tr '[:upper:]' '[:lower:]')
MESSAGE="\$2"

if [[ -z "\$RECIPIENT" || -z "\$MESSAGE" ]]; then
  echo "Uso: ./agents/msg.sh <destinatario> \"<messaggio>\""
  echo "Destinatari: $CEO_LOWER, $ENGINEER_LOWER, $PRODUCT_LOWER, $MARKETING_LOWER, $UIUX_LOWER, $TESTER_LOWER"
  exit 1
fi

case "\$RECIPIENT" in
  $CEO_LOWER)       WINDOW_NAME="$CEO_NAME" ;;
  $ENGINEER_LOWER)  WINDOW_NAME="$ENGINEER_NAME" ;;
  $PRODUCT_LOWER)   WINDOW_NAME="$PRODUCT_NAME" ;;
  $MARKETING_LOWER) WINDOW_NAME="$MARKETING_NAME" ;;
  $UIUX_LOWER)      WINDOW_NAME="$UIUX_NAME" ;;
  $TESTER_LOWER)    WINDOW_NAME="$TESTER_NAME" ;;
  *)
    echo "Destinatario '\$RECIPIENT' non riconosciuto."
    echo "Destinatari validi: $CEO_LOWER, $ENGINEER_LOWER, $PRODUCT_LOWER, $MARKETING_LOWER, $UIUX_LOWER, $TESTER_LOWER"
    exit 1
    ;;
esac

osascript << APPLESCRIPT
tell application "iTerm2"
  set delivered to false
  repeat with aWindow in windows
    repeat with aTab in tabs of aWindow
      repeat with aSession in sessions of aTab
        if profile name of aSession contains "\$WINDOW_NAME" then
          tell aSession
            write text "MESSAGGIO IN ARRIVO - metti in coda: \$MESSAGE"
          end tell
          set delivered to true
          exit repeat
        end if
      end repeat
      if delivered then exit repeat
    end repeat
    if delivered then exit repeat
  end repeat
  if not delivered then
    display notification "Finestra '\$WINDOW_NAME' non trovata in iTerm2." with title "msg.sh — errore"
  end if
end tell
APPLESCRIPT

echo "Messaggio inviato a \$WINDOW_NAME."
EOF

chmod +x "$TARGET_DIR/agents/msg.sh"
```

- [ ] **Step 2: Verifica sintassi**

```bash
bash -n setup.sh
```

Expected: nessun output

- [ ] **Step 3: Commit**

```bash
git add setup.sh
git commit -m "feat: setup.sh — genera msg.sh con nomi agenti aggiornati"
```

---

### Task 6: Copia e trasforma i file degli agenti (SOUL.md, IDENTITY.md)

**Files:**
- Modify: `setup.sh`

- [ ] **Step 1: Definisci la funzione di sostituzione nomi**

Questa funzione applica tutte e 6 le sostituzioni su un file sorgente e scrive il risultato nella destinazione. Va bene usarla su ogni file perché i nomi default sono unici.

```bash
substitute_names() {
  local SRC="$1"
  local DST="$2"
  sed \
    -e "s/Alessio/$CEO_NAME/g" \
    -e "s/Stefano/$ENGINEER_NAME/g" \
    -e "s/Walter/$PRODUCT_NAME/g" \
    -e "s/Veronica/$MARKETING_NAME/g" \
    -e "s/Alessandra/$UIUX_NAME/g" \
    -e "s/Marwen/$TESTER_NAME/g" \
    -e "s/alessio/${CEO_LOWER}/g" \
    -e "s/stefano/${ENGINEER_LOWER}/g" \
    -e "s/walter/${PRODUCT_LOWER}/g" \
    -e "s/veronica/${MARKETING_LOWER}/g" \
    -e "s/alessandra/${UIUX_LOWER}/g" \
    -e "s/marwen/${TESTER_LOWER}/g" \
    "$SRC" > "$DST"
}
```

Nota: la funzione va definita DOPO la definizione delle variabili `*_LOWER` (Task 5, Step 1).

- [ ] **Step 2: Copia SOUL.md e IDENTITY.md per ogni agente**

```bash
echo "Copia file agenti..."

# CEO
substitute_names "$SCRIPT_DIR/agents/ceo/SOUL.md"      "$TARGET_DIR/agents/ceo/SOUL.md"
substitute_names "$SCRIPT_DIR/agents/ceo/IDENTITY.md"  "$TARGET_DIR/agents/ceo/IDENTITY.md"

# Engineer
substitute_names "$SCRIPT_DIR/agents/engineer/SOUL.md"     "$TARGET_DIR/agents/engineer/SOUL.md"
substitute_names "$SCRIPT_DIR/agents/engineer/IDENTITY.md" "$TARGET_DIR/agents/engineer/IDENTITY.md"

# Product
substitute_names "$SCRIPT_DIR/agents/product/SOUL.md"     "$TARGET_DIR/agents/product/SOUL.md"
substitute_names "$SCRIPT_DIR/agents/product/IDENTITY.md" "$TARGET_DIR/agents/product/IDENTITY.md"

# Marketing
substitute_names "$SCRIPT_DIR/agents/marketing/SOUL.md"     "$TARGET_DIR/agents/marketing/SOUL.md"
substitute_names "$SCRIPT_DIR/agents/marketing/IDENTITY.md" "$TARGET_DIR/agents/marketing/IDENTITY.md"

# UI/UX
substitute_names "$SCRIPT_DIR/agents/uiux/SOUL.md"     "$TARGET_DIR/agents/uiux/SOUL.md"
substitute_names "$SCRIPT_DIR/agents/uiux/IDENTITY.md" "$TARGET_DIR/agents/uiux/IDENTITY.md"

# Tester
substitute_names "$SCRIPT_DIR/agents/tester/SOUL.md"     "$TARGET_DIR/agents/tester/SOUL.md"
substitute_names "$SCRIPT_DIR/agents/tester/IDENTITY.md" "$TARGET_DIR/agents/tester/IDENTITY.md"

echo "✓ SOUL.md e IDENTITY.md copiati."
```

- [ ] **Step 3: Verifica sintassi**

```bash
bash -n setup.sh
```

Expected: nessun output

- [ ] **Step 4: Commit**

```bash
git add setup.sh
git commit -m "feat: setup.sh — copia e trasforma SOUL.md e IDENTITY.md"
```

---

### Task 7: Copia i file rimanenti (HEARTBEAT, log files, examples)

**Files:**
- Modify: `setup.sh`

- [ ] **Step 1: Copia HEARTBEAT.md e file di log per ogni agente**

```bash
# HEARTBEAT.md (identici per tutti i progetti)
cp "$SCRIPT_DIR/agents/ceo/HEARTBEAT.md"       "$TARGET_DIR/agents/ceo/HEARTBEAT.md"
cp "$SCRIPT_DIR/agents/engineer/HEARTBEAT.md"  "$TARGET_DIR/agents/engineer/HEARTBEAT.md"
cp "$SCRIPT_DIR/agents/product/HEARTBEAT.md"   "$TARGET_DIR/agents/product/HEARTBEAT.md"
cp "$SCRIPT_DIR/agents/marketing/HEARTBEAT.md" "$TARGET_DIR/agents/marketing/HEARTBEAT.md"
cp "$SCRIPT_DIR/agents/uiux/HEARTBEAT.md"      "$TARGET_DIR/agents/uiux/HEARTBEAT.md"
cp "$SCRIPT_DIR/agents/tester/HEARTBEAT.md"    "$TARGET_DIR/agents/tester/HEARTBEAT.md"

# File di log specifici per ruolo
cp "$SCRIPT_DIR/agents/engineer/BUILD-LOG.md"         "$TARGET_DIR/agents/engineer/BUILD-LOG.md"
cp "$SCRIPT_DIR/agents/product/BACKLOG.md"            "$TARGET_DIR/agents/product/BACKLOG.md"
cp "$SCRIPT_DIR/agents/marketing/CONTENT-CALENDAR.md" "$TARGET_DIR/agents/marketing/CONTENT-CALENDAR.md"
cp "$SCRIPT_DIR/agents/uiux/UI-REVIEW-LOG.md"         "$TARGET_DIR/agents/uiux/UI-REVIEW-LOG.md"
cp "$SCRIPT_DIR/agents/tester/BUG-LOG.md"             "$TARGET_DIR/agents/tester/BUG-LOG.md"
cp "$SCRIPT_DIR/agents/tester/TEST-CHECKLIST.md"      "$TARGET_DIR/agents/tester/TEST-CHECKLIST.md"

echo "✓ File di log e heartbeat copiati."
```

- [ ] **Step 2: Copia la cartella examples/**

```bash
cp -r "$SCRIPT_DIR/examples/." "$TARGET_DIR/examples/"
echo "✓ Esempi copiati."
```

- [ ] **Step 3: Verifica sintassi**

```bash
bash -n setup.sh
```

Expected: nessun output

- [ ] **Step 4: Commit**

```bash
git add setup.sh
git commit -m "feat: setup.sh — copia HEARTBEAT, log files e examples"
```

---

### Task 8: Messaggio finale e test end-to-end

**Files:**
- Modify: `setup.sh`

- [ ] **Step 1: Aggiungi il messaggio finale**

```bash
# ── Fine ──────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   ✓ Setup completato!                    ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "Il sistema multi-agente è stato installato in:"
echo "  $TARGET_DIR"
echo ""
echo "Prossimi passi:"
echo "  1. cd $TARGET_DIR"
echo "  2. Apri con Claude Code: claude ."
echo "  3. Raffina shared-context/THESIS.md con la visione reale del progetto"
echo "  4. Aggiorna shared-context/ROADMAP.md con le priorità attuali"
echo "  5. Lancia i 6 agenti nelle finestre iTerm2"
echo ""
echo "Suggerimento: usa 'cat shared-context/THESIS.md' e chiedi a Claude"
echo "di riscriverla sulla base di quello che sai del progetto."
echo ""
```

- [ ] **Step 2: Verifica sintassi finale dello script**

```bash
bash -n setup.sh
```

Expected: nessun output

- [ ] **Step 3: Esegui il test end-to-end in una directory temporanea**

```bash
TEST_DIR="/tmp/test-the-office-$(date +%s)"
./setup.sh
# Inserisci: $TEST_DIR come directory
# Inserisci: test-project come nome progetto
# Inserisci: "Una piattaforma di test" come descrizione
# Inserisci: "Node.js, React" come tech stack
# Lascia tutti i nomi agenti ai default (invio)
```

- [ ] **Step 4: Verifica i file generati**

```bash
# Controlla che tutti i file esistano
ls "$TEST_DIR"
ls "$TEST_DIR/agents/"
ls "$TEST_DIR/shared-context/"

# Controlla che il nome progetto sia presente nei file
grep "test-project" "$TEST_DIR/CLAUDE.md"
grep "test-project" "$TEST_DIR/shared-context/THESIS.md"

# Controlla che i nomi default siano presenti
grep "Stefano" "$TEST_DIR/agents/engineer/SOUL.md"
grep "Alessio" "$TEST_DIR/agents/ceo/IDENTITY.md"

# Controlla msg.sh
cat "$TEST_DIR/agents/msg.sh"
```

Expected: tutti i file esistono, le sostituzioni sono corrette

- [ ] **Step 5: Pulizia directory di test**

```bash
rm -rf "$TEST_DIR"
```

- [ ] **Step 6: Commit finale**

```bash
git add setup.sh
git commit -m "feat: setup.sh — messaggio finale e script completo"
```
