# Comandi

Reference di tutti gli script. Gli id degli agenti vengono sempre da `shared-context/TEAM.json`: se ne sbagli uno, lo script ti elenca quelli validi ed esce con codice 1.

## setup.sh — comporre un team

```bash
./setup.sh                                        # wizard, esporta in exports/<slug>/
./setup.sh --config <file>                        # non interattivo, esporta
./setup.sh --config <file> --target <dir>         # installa direttamente
./setup.sh --help
```

**Predefinito è l'export**: il team finisce in `exports/<slug-del-progetto>/` come bundle autonomo, e nessun progetto esistente viene toccato. `--target` installa direttamente, ed è la strada giusta solo su una directory vuota.

| Opzione | Effetto |
|---------|---------|
| `--config <file>` | Legge il team da un JSON invece di chiederlo. Salta ogni schermata |
| `--target <dir>` | Installa in `<dir>` invece di esportare. Anche `project.target` nel config |
| `--export-dir <dir>` | Radice degli export. Default `./exports` |
| `--save-config <file>` | Copia la configurazione usata, per rifare lo stesso setup altrove |
| `--force` | Consente di scrivere in una `--target` non vuota, o di rigenerare un team esistente |

Il bundle esportato contiene un `INTEGRAZIONE.md` con i comandi per innestarlo, compreso il caso in cui il progetto abbia già un `CLAUDE.md`.

Formato del file di configurazione:

```json
{
  "project": {
    "name": "acme-shop",
    "description": "E-commerce per ricambi auto",
    "stack": "Laravel, Vue, MySQL",
    "brand": "Acme",
    "target": "~/Code/acme-shop"
  },
  "team": [
    { "role": "pm",      "name": "Giulia" },
    { "role": "backend", "name": "Marco" }
  ]
}
```

Regole validate prima di scrivere qualsiasi cosa. Ognuna esce con codice 2:

- il team non può essere vuoto
- la prima persona deve avere un ruolo di coordinamento
- ogni `role` deve esistere nel catalogo
- ogni persona deve avere un nome che produca un id valido
- due persone non possono produrre lo stesso id
- l'export di destinazione non deve esistere già (un bundle non si sovrascrive)
- una `--target` non vuota richiede `--force`, o conferma esplicita in interattivo

## hire.sh — aggiungere una persona

```bash
./agents/hire.sh                       # interattivo, richiede gum
./agents/hire.sh <ruolo> "<Nome>"      # diretto, senza gum
```

Esempi:

```bash
./agents/hire.sh security "Niccolò"
./agents/hire.sh backend "Luca"        # secondo backend: nessun problema
```

Crea la cartella persona, aggiunge la voce al manifest con un colore non ancora usato, registra la persona come `STANDBY` e crea inbox e coda. Se un passo fallisce i precedenti vengono annullati.

Rimuovere una persona non è previsto: cancellare log, inbox e messaggi inviati è una decisione che merita più di un comando.

## setstatus.sh — dichiarare cosa stai facendo

```bash
./agents/setstatus.sh <id> WORKING "<task>"
./agents/setstatus.sh <id> IDLE
./agents/setstatus.sh <id> STANDBY
```

`WORKING` richiede una descrizione del task: uno stato senza contenuto non dice niente a chi guarda la dashboard.

| Stato | Significato |
|-------|-------------|
| `WORKING` | Sta lavorando su qualcosa di specifico |
| `IDLE` | Disponibile, in attesa di lavoro |
| `STANDBY` | Sessione chiusa |

## with-status.sh — status automatico attorno a un comando

```bash
./agents/with-status.sh <id> "<task>" -- <comando> [args...]
```

```bash
./agents/with-status.sh marco "Suite di integrazione" -- npm test
```

Segna `WORKING`, esegue, e rimette `IDLE` anche se il comando fallisce o viene interrotto.

## msg.sh — mandare un messaggio

```bash
./agents/msg.sh <mittente> <destinatario> "<testo>"
```

```bash
./agents/msg.sh marco davide "Schema pronto in database/migrations. Verifica i vincoli."
```

Il mittente è obbligatorio: un messaggio anonimo non si può confermare né a cui rispondere. Il messaggio finisce in tre posti — il log, l'inbox del destinatario, e la sua finestra iTerm2.

`OFFICE_NO_ITERM=1` salta la consegna nella finestra. Il messaggio resta su log e inbox, che sono la consegna vera.

## ack.sh — confermare la ricezione

```bash
./agents/ack.sh <msg-id> <id-di-chi-conferma>
```

Scrive un evento `ACK` nel log, rimuove il file dall'inbox e notifica il mittente. **Conferma ogni messaggio ricevuto prima di rispondere**: è ciò che permette a chi coordina di distinguere un messaggio ignorato da uno in lavorazione.

## qtask.sh — la coda di lavoro

```bash
./agents/qtask.sh add  <id> "<descrizione>"   # accoda, stampa l'id del task
./agents/qtask.sh list <id>                   # cosa è pendente
./agents/qtask.sh done <id> <task-id>         # rimuove dalla coda
```

Un task va in coda quando arriva mentre l'agente sta già lavorando su altro. La coda è visibile nella dashboard, e serve a chi coordina per vedere chi è saturo.

## dashboard.sh e live-dashboard.sh — lo stato del team

```bash
./agents/dashboard.sh                 # snapshot
./agents/live-dashboard.sh            # refresh continuo, Ctrl+C per uscire
REFRESH=10 ./agents/live-dashboard.sh # intervallo personalizzato
```

Mostra una riga per persona: nome, ruolo, stato, task in coda, task corrente. Chi è in `AGENT-STATUS.json` ma non nel manifest non viene mostrato: il manifest è la verità.

## launch.sh — avviare un agente

```bash
./agents/launch.sh <id>
./agents/launch.sh --dry-run <id>     # stampa il prompt invece di lanciarlo
./agents/launch.sh                    # elenca gli agenti del team
```

Costruisce il prompt dalla cartella indicata dal manifest e avvia Claude Code. Se `SOUL.md` manca, il prompt istruisce l'agente a scriverlo prima di procedere.

`--dry-run` serve a verificare cosa verrebbe passato, senza consumare una sessione.

## iterm.sh — una finestra per agente

```bash
./agents/iterm.sh all                 # tutti + dashboard
./agents/iterm.sh <id>                # uno solo
./agents/iterm.sh dashboard           # solo la dashboard live
./agents/iterm.sh --dry-run all       # cosa aprirebbe, senza aprirlo
```

Ogni finestra riceve un nome di sessione (il nome della persona) e uno sfondo derivato dal colore del manifest, scurito perché resti leggibile. Il nome di sessione è ciò che permette a `msg.sh` di trovare la finestra.

Solo macOS con iTerm2.

## tests/run.sh — la suite

```bash
git submodule update --init --recursive   # una volta
./tests/run.sh                            # tutto: 134 test, ~45 secondi
./tests/run.sh tests/team-lib.bats        # un file

OFFICE_TUI_TESTS=1 ./tests/run.sh tests/tui-interactive.bats   # le schermate gum
```

Vedi [Testing](testing.md).

## Codici di uscita

| Codice | Significato |
|--------|-------------|
| 0 | Tutto bene |
| 1 | Errore d'uso: argomento mancante, id sconosciuto, stato non valido |
| 2 | Errore di configurazione: manifest o catalogo mancante o corrotto, config non valida, `gum` assente e rifiutato |

La distinzione conta negli script: 1 vuol dire "hai sbagliato comando", 2 vuol dire "il progetto non è in uno stato utilizzabile".
