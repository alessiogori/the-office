#!/usr/bin/env bash
# tui.sh — schermate gum condivise da setup.sh e hire.sh.
# Nessuna di queste funzioni viene chiamata sui percorsi ad argomenti:
# assumere e generare deve restare possibile su una macchina senza gum.

TUI_NAME_POOL="Giulia Marco Luca Sofia Matteo Chiara Andrea Elena Davide Sara Federico Martina Lorenzo Alice Simone Giorgia"

tui_suggest_name() {
  local index="$1" i=0 name
  for name in $TUI_NAME_POOL; do
    if [ "$i" -eq "$((index % 16))" ]; then
      echo "$name"
      return 0
    fi
    i=$((i + 1))
  done
  echo "Persona$((index + 1))"
}

tui_gum_available() {
  [ -z "${OFFICE_ASSUME_NO_GUM:-}" ] && command -v gum >/dev/null 2>&1
}

tui_install_hint() {
  if command -v brew >/dev/null 2>&1; then
    echo "brew install gum"
  elif command -v apt-get >/dev/null 2>&1; then
    echo "sudo apt-get install gum"
  elif command -v go >/dev/null 2>&1; then
    echo "go install github.com/charmbracelet/gum@latest"
  else
    echo "Vedi https://github.com/charmbracelet/gum#installation"
  fi
}

tui_require_gum() {
  if tui_gum_available; then
    return 0
  fi

  local hint answer
  hint="$(tui_install_hint)"

  echo ""
  echo "Questo wizard usa gum per le schermate interattive."
  echo "gum è un piccolo strumento a riga di comando per menu e input:"
  echo "https://github.com/charmbracelet/gum"
  echo ""
  echo "Comando di installazione per questo sistema:"
  echo "  $hint"
  echo ""
  printf "Lo installo ora? [s/N]: "
  read -r answer

  if [ "$(echo "$answer" | tr '[:upper:]' '[:lower:]')" = "s" ]; then
    if eval "$hint" && tui_gum_available; then
      return 0
    fi
    echo "Installazione non riuscita. Installa gum a mano e rilancia." >&2
    exit 2
  fi

  echo ""
  echo "Annullato. Installa gum con:"
  echo "  $hint"
  echo ""
  echo "In alternativa usa la modalità non interattiva:"
  echo "  ./setup.sh --config <file.json> --target <directory>"
  exit 2
}

# tui_pick_role <header> → stampa lo slug scelto
tui_pick_role() {
  local header="$1" line
  line=$(roster_choices | gum filter --height 18 --placeholder "cerca un ruolo…" --header "$header")
  [ -n "$line" ] || return 1
  printf '%s' "$line" | cut -f2
}

# tui_pick_coordinator → stampa lo slug scelto tra i coordinatori
tui_pick_coordinator() {
  local line
  line=$(roster_coordinator_choices | gum choose --height 8 \
    --header "Chi coordina il lavoro degli altri? (obbligatorio)")
  [ -n "$line" ] || return 1
  printf '%s' "$line" | cut -f2
}

# tui_ask_name <suggerito> → stampa il nome confermato
tui_ask_name() {
  gum input --value "$1" --placeholder "Nome della persona" --header "Come si chiama?"
}
