#!/bin/zsh
# The Office — Launch agent
# Uso: ./agents/launch.sh <agente>
# Esempio: ./agents/launch.sh stefano

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

case "$1" in
  alessio|ceo)
    claude "Sei Alessio, il CEO. Leggi agents/ceo/SOUL.md e agents/ceo/IDENTITY.md. Poi controlla i HEARTBEAT.md di tutti gli agenti e shared-context/THESIS.md. Imposta le priorità della sessione."
    ;;
  stefano|engineer)
    claude "Sei Stefano, l'Engineer. Leggi agents/engineer/SOUL.md e agents/engineer/IDENTITY.md. Controlla agents/engineer/BUILD-LOG.md per il contesto della sessione precedente e inizia."
    ;;
  walter|product)
    claude "Sei Walter, il Product Lead. Leggi agents/product/SOUL.md e agents/product/IDENTITY.md. Controlla agents/product/BACKLOG.md e shared-context/ROADMAP.md."
    ;;
  veronica|marketing)
    claude "Sei Veronica, la responsabile Marketing. Leggi agents/marketing/SOUL.md e agents/marketing/IDENTITY.md. Controlla agents/marketing/CONTENT-CALENDAR.md per le pendenze."
    ;;
  alessandra|uiux)
    claude "Sei Alessandra, la UI/UX Specialist. Leggi agents/uiux/SOUL.md e agents/uiux/IDENTITY.md. Controlla agents/uiux/UI-REVIEW-LOG.md e verifica cosa ha spedito Stefano dall'ultima sessione."
    ;;
  marwen|tester)
    claude "Sei Marwen, il Tester. Leggi agents/tester/SOUL.md e agents/tester/IDENTITY.md. Controlla agents/tester/BUG-LOG.md e agents/tester/TEST-CHECKLIST.md. Verifica cosa ha passato Alessandra."
    ;;
  *)
    echo "Agenti disponibili:"
    echo "  alessio    (CEO)"
    echo "  stefano    (Engineer)"
    echo "  walter     (Product)"
    echo "  veronica   (Marketing)"
    echo "  alessandra (UI/UX)"
    echo "  marwen     (Tester)"
    echo ""
    echo "Uso: ./agents/launch.sh <nome>"
    ;;
esac
