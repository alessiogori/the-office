# Testing

La suite usa [bats-core](https://github.com/bats-core/bats-core), incluso come submodule: chi clona con `--recurse-submodules` può eseguire i test senza installare niente.

## Eseguire

```bash
git submodule update --init --recursive   # una volta, se hai clonato senza
./tests/run.sh                            # tutta la suite
./tests/run.sh tests/team-lib.bats        # un file solo
```

La suite completa impiega circa 45 secondi.

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
| `tui-interactive.bats` | Il wizard vero, pilotato via pty. Opt-in, vedi sotto |
| `hire.bats` | Aggiunta di una persona, rollback incluso |

## Perché è veloce

Due scelte, entrambe misurate. La suite è passata da 196 a 45 secondi senza togliere un solo test.

**Le fixture condivise.** `setup-wizard.bats` ha 29 test, e la maggior parte si limita a ispezionare un progetto generato. Generarne uno per test costava 145 secondi. `setup_file()` ne produce due una volta sola — un'installazione diretta e un export — e i test di sola lettura li riusano attraverso `$T` e `$B`. Solo chi muta lo stato o usa una configurazione diversa genera il proprio, e nel file è marcato con `# genera il proprio`.

**Un processo python invece di quindici.** `roster_generate_person` chiamava `roster_role_get` quattordici volte, e ognuna riapriva e riparsava il catalogo da 36 ruoli: su un team di cinque persone erano settanta letture dello stesso file. Ora è un blocco python unico che legge il catalogo una volta e scrive tutti i file della persona. Una generazione è passata da 7,4 a 2,0 secondi.

Nella stessa direzione, `team_require_manifest` verifica il manifest una volta per processo invece che a ogni `team_get`.

Se aggiungi test a `setup-wizard.bats`, chiediti se ti serve davvero un progetto nuovo. Quasi sempre no.

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

### I test opt-in del wizard

`tests/tui-interactive.bats` pilota le schermate `gum` vere con `expect`, attraverso uno pseudo-terminale. Girano solo con un opt-in esplicito, da un terminale interattivo:

```bash
OFFICE_TUI_TESTS=1 ./tests/run.sh tests/tui-interactive.bats
```

Altrove si saltano, e la ragione è concreta: sotto bats lo stdin è `/dev/null`, e in quelle condizioni `expect` non riesce a stabilire lo pty — il test non fallisce, si appende. Un test che si appende è peggio di un test assente, quindi la condizione è esplicita invece che sperata.

Due trappole se tocchi `tests/helpers/drive-wizard.exp`:

- **La geometria dello pty va impostata a mano.** Nasce senza dimensioni, e con larghezza zero la `textinput` di gum va in panico. `stty rows 40 columns 120` sullo slave, altrimenti il test fallisce per un motivo che non c'entra col codice sotto test.
- **I campi hanno un valore di default.** Vanno svuotati con dei backspace prima di scrivere, altrimenti il testo si accoda a quello che c'è già.

### Il resto

`gum` non si pilota da un test normale. La regola che rende il sistema testabile è che **ogni comando interattivo ha una forma ad argomenti equivalente**:

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
