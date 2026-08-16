#!/usr/bin/env bash
# run.sh — esegue la suite bats.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATS="$SCRIPT_DIR/bats/bats-core/bin/bats"

if [ ! -x "$BATS" ]; then
  echo "Errore: bats-core non trovato in tests/bats/." >&2
  echo "Inizializza i submodule con: git submodule update --init --recursive" >&2
  exit 2
fi

exec "$BATS" "${@:-$SCRIPT_DIR}"
