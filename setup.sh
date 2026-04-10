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
