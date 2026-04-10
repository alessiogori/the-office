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
