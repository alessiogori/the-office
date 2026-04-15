#!/bin/zsh
# The Office — Launch agent
# Uso: ./agents/launch.sh <agente>
# Esempio: ./agents/launch.sh stefano

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

WAIT_MSG="Poi rispondi con un unico messaggio di ready (es: '[Nome] pronto. In attesa del via.') e NON fare null'altro: nessuna analisi, nessun file aggiuntivo, nessuna proposta. Aspetta il primo comando esplicito."

case "$1" in
  alessio|ceo)
    claude "Sei Alessio, il CEO. Leggi agents/ceo/SOUL.md e agents/ceo/IDENTITY.md. $WAIT_MSG"
    ;;
  stefano|engineer)
    claude "Sei Stefano, l'Engineer. Leggi agents/engineer/SOUL.md e agents/engineer/IDENTITY.md. $WAIT_MSG"
    ;;
  walter|product)
    claude "Sei Walter, il Product Lead. Leggi agents/product/SOUL.md e agents/product/IDENTITY.md. $WAIT_MSG"
    ;;
  veronica|marketing)
    claude "Sei Veronica, la responsabile Marketing. Leggi agents/marketing/SOUL.md e agents/marketing/IDENTITY.md. $WAIT_MSG"
    ;;
  alessandra|uiux)
    claude "Sei Alessandra, la UI/UX Specialist. Leggi agents/uiux/SOUL.md e agents/uiux/IDENTITY.md. $WAIT_MSG"
    ;;
  marwen|tester)
    claude "Sei Marwen, il Tester. Leggi agents/tester/SOUL.md e agents/tester/IDENTITY.md. $WAIT_MSG"
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
