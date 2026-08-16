# Testing

La suite usa [bats-core](https://github.com/bats-core/bats-core), incluso come submodule: chi clona con `--recurse-submodules` può eseguire i test senza installare niente.

## Eseguire

```bash
git submodule update --init --recursive   # una volta, se hai clonato senza
./tests/run.sh                            # tutta la suite
./tests/run.sh tests/team-lib.bats        # un file solo
```

La suite completa impiega qualche minuto: `setup-wizard.bats` genera progetti veri, uno per test.

## Com'è organizzata

| File | Copre |
|------|-------|
| `smoke.bats` | Che l'infrastruttura stessa funzioni |
| `catalog.bats` | Validità di `catalog/roles.json`, template, anime |
| `team-lib.bats` | `agents/lib/team.sh` |
| `roster-lib.bats` | `agents/lib/roster.sh` e la generazione delle cartelle |
| `tui-lib.bats` | `agents/lib/tui.sh` e il preflight gum |
| `scripts.bats` | setstatus, qtask, launch, iterm, dashboard |
| `messaging.bats` | msg e ack |
| `setup-wizard.bats` | Generazione end-to-end via `--config` |
| `hire.bats` | Aggiunta di una persona, rollback incluso |

## L'isolamento

Ogni test che tocca lo stato chiama `setup_office_test`, che crea una directory temporanea e la esporta come `OFFICE_SHARED_DIR`. Tutti gli script rispettano quella variabile, quindi **nessun test scrive nella `shared-context/` reale**.

```bash
setup() {
  setup_office_test          # TMPDIR isolata, OFFICE_SHARED_DIR esportata
  use_manifest team-valid.json
}
teardown() { teardown_office_test; }
```

Non è un dettaglio di comodità. Prima che gli script rispettassero `OFFICE_SHARED_DIR`, un giro di test ha sovrascritto lo stato reale degli agenti di questo repo. Se aggiungi uno script che scrive in `shared-context/`, **fallo passare da `OFFICE_SHARED_DIR`** o il primo test lo scoprirà nel modo peggiore.

## Le fixture

| File | Contenuto |
|------|-----------|
| `team-valid.json` | Tre persone, ruoli diversi, un coordinatore |
| `team-duplicates.json` | Due persone sullo stesso ruolo — il caso che rompe le assunzioni |
| `team-corrupt.json` | JSON troncato, per verificare i messaggi d'errore |

Installale con `use_manifest <nome>`.

## Testare codice interattivo

`gum` non si pilota da un test. La regola che rende il sistema testabile è che **ogni comando interattivo ha una forma ad argomenti equivalente**:

```bash
./agents/hire.sh backend "Marco"    # nessun gum, stesso risultato
./setup.sh --config team.json       # nessun gum, stesso risultato
```

Si testa quello che sta intorno alla TUI: il preflight, il rilevamento del gestore di pacchetti, il fatto che un rifiuto esca con codice 2 senza scrivere niente. `OFFICE_ASSUME_NO_GUM=1` simula l'assenza di gum.

Stessa logica per iTerm2: `OFFICE_NO_ITERM=1` salta la consegna AppleScript, e il test verifica che il messaggio finisca comunque su log e inbox.

## Scrivere un test

```bash
#!/usr/bin/env bats

load 'helpers/setup'

setup() {
  setup_office_test
  use_manifest team-valid.json
}
teardown() { teardown_office_test; }

@test "setstatus rifiuta un agente fuori dal manifest" {
  run "$OFFICE_ROOT/agents/setstatus.sh" pippo WORKING "qualcosa"
  assert_failure
  assert_output --partial "pippo"
}
```

Note pratiche:

- `run` cattura stdout, stderr e codice di uscita. Senza `run`, un comando che fallisce interrompe il test.
- `$OFFICE_ROOT` è la radice del repo. Usa percorsi assoluti: bats cambia directory.
- Per verificare un codice specifico: `[ "$status" -eq 2 ]`. `assert_failure` accetta qualsiasi codice diverso da zero.
- `refute_output --partial "Traceback"` è il modo per verificare che un errore sia un messaggio e non un crash di Python.

## Cosa vale la pena testare

La suite copre i modi in cui questo sistema si rompe davvero:

- **Validazione**: un id fuori dal manifest viene rifiutato, con la lista di quelli validi nel messaggio
- **Ruoli duplicati**: due persone sullo stesso ruolo restano distinte in ogni script
- **Manifest mancante o corrotto**: codice 2 e un messaggio, mai un traceback
- **Atomicità**: se `hire.sh` fallisce a metà, non resta mezzo agente
- **Isolamento**: `OFFICE_SHARED_DIR` è rispettata ovunque
- **Coerenza dei dati**: ogni `collaborates` punta a uno slug esistente, ogni `logTemplate` a un file esistente

Un test che verifica che il codice faccia quello che il codice fa non serve. Un test che verifica che un errore utente produca un messaggio utile, sì.

## Prima di aprire una PR

```bash
./tests/run.sh
bash -n <ogni script modificato>          # controllo sintattico
```

E se hai toccato `catalog/roles.json`:

```bash
python3 docs/genera-catalogo.py > docs/catalogo-ruoli.md
```
