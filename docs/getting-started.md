# Guida introduttiva

Dal clone al primo agente che lavora.

## Requisiti

| Cosa | Perché | Obbligatorio |
|------|--------|--------------|
| `bash` 3.2+ | Tutti gli script. macOS ne ha uno di serie | sì |
| `python3` | Lettura e scrittura JSON. Nessun `jq` richiesto | sì |
| [`gum`](https://github.com/charmbracelet/gum) | Le schermate del wizard | solo per il percorso interattivo |
| `iTerm2` | Consegna dei messaggi tra agenti su macOS | no, ma consigliato |
| `git` con submodule | La suite di test | solo per contribuire |

Se `gum` manca, il wizard te lo dice e propone il comando giusto per il tuo sistema (`brew install gum` su macOS). Puoi anche non installarlo e usare la modalità con file di configurazione.

## Installazione

```bash
git clone --recurse-submodules https://github.com/alessiogori/the-office.git
cd the-office
./setup.sh
```

Se hai già clonato senza `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

I submodule servono solo a far girare i test. Il sistema funziona anche senza.

Non serve altro: niente Node, niente Rust, niente compilazione. Sono script bash, dati JSON e markdown.

## Il wizard

Sei schermate, in quest'ordine.

**1. Il progetto.** Nome, descrizione, stack tecnologico, brand. Non chiede una directory: il team viene **esportato** come bundle in `exports/<nome-progetto>/`, e nessun progetto esistente viene toccato. Se esiste già un export con quel nome, te lo dice e ti fa scegliere un altro nome.

**2. Quante persone.** Da 1 a 12. Il tetto non è arbitrario: ogni agente è un terminale aperto, e oltre la dozzina il coordinamento costa più di quanto renda.

**3. Chi coordina.** Obbligatorio, e sempre la prima persona. Si sceglie tra cinque figure: CEO, Project Manager, Tech Lead, Delivery Lead, Chief of Staff. Un team senza qualcuno che arbitra i conflitti non è un team, è un elenco di processi.

**4. I ruoli.** Uno slot alla volta, con ricerca incrementale sulle 36 figure del catalogo. Puoi scegliere lo stesso ruolo più volte: due backend engineer sono due persone diverse.

**5. I nomi.** Ogni slot propone un nome, che puoi cambiare. Il nome diventa l'`id` dell'agente, normalizzato: `Niccolò` → `niccolo`. Due nomi che producono lo stesso id vengono rifiutati.

**6. Conferma.** Il wizard mostra il team e chiede il via. Prima di quel sì non viene scritto niente su disco.

## Il bundle esportato

Il risultato è un albero autonomo in `exports/<slug>/`: non dipende da the-office, e lo copi dove vuoi. Contiene anche un `INTEGRAZIONE.md` scritto sul tuo team, con i comandi per innestarlo.

**Progetto nuovo o senza `CLAUDE.md`:**

```bash
cp -R exports/acme-shop/. ~/Code/acme-shop/
```

**Progetto che ha già un `CLAUDE.md`:** copia tutto tranne i file di configurazione, poi appendi la sezione agenti invece di sostituire il file. `INTEGRAZIONE.md` riporta i comandi esatti, incluso l'avviso su `shared-context/`: `THESIS.md`, `ROADMAP.md` e `BRAND-GUIDE.md` contengono segnaposto, e se il progetto ha già una sua visione non vanno sovrascritti.

### Installare direttamente

Se parti da una directory vuota e vuoi saltare il passaggio:

```bash
./setup.sh --config team.json --target ~/Code/mio-progetto
```

Su una directory **non vuota** il comando si ferma: in interattivo chiede conferma, in modalità `--config` rifiuta e richiede `--force`. Il setup sovrascrive `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `.gitignore` e i file di `shared-context/` senza fonderli, quindi su un progetto vivo l'export resta la strada giusta.

## Senza il wizard

Utile per rifare lo stesso setup su più progetti, per il CI, o su una macchina senza `gum`:

```bash
./setup.sh --config team.json --export-dir ./exports
```

```json
{
  "project": {
    "name": "acme-shop",
    "description": "E-commerce per ricambi auto",
    "stack": "Laravel, Vue, MySQL",
    "brand": "Acme"
  },
  "team": [
    { "role": "pm",       "name": "Giulia" },
    { "role": "backend",  "name": "Marco" },
    { "role": "backend",  "name": "Luca" },
    { "role": "security", "name": "Niccolò" },
    { "role": "tester",   "name": "Davide" }
  ]
}
```

Valgono le stesse regole del wizard: la prima persona deve avere un ruolo di coordinamento, i ruoli devono esistere nel catalogo, gli id devono essere univoci. Se una regola non è rispettata il comando esce con codice 2 e ti dice quale.

Per catturare le scelte di una sessione interattiva e riusarle:

```bash
./setup.sh --save-config team.json
```

## Cosa contiene il bundle

```
exports/acme-shop/
├── INTEGRAZIONE.md                   ← come innestarlo in un progetto esistente
├── CLAUDE.md, AGENTS.md, GEMINI.md   ← generati dal tuo team, non da un modello fisso
├── agents/
│   ├── lib/                          ← team.sh, roster.sh, tui.sh
│   ├── _authoring/                   ← come si scrive un'anima
│   ├── giulia/  marco/  luca/  …     ← una cartella per persona
│   └── *.sh                          ← msg, ack, setstatus, qtask, hire, …
├── catalog/roles.json                ← le 36 figure, per assumere in futuro
├── shared-context/
│   ├── TEAM.json                     ← chi c'è: la sorgente di verità
│   ├── THESIS.md, ROADMAP.md, BRAND-GUIDE.md
│   ├── inbox/<id>/  queues/<id>.json
└── docs/sessions/
```

Ogni cartella persona contiene `IDENTITY.md` (confini), `HEARTBEAT.md` (stato), `ROLE-BRIEF.md` (i dati del ruolo), il log di ruolo se previsto, e `SOUL.md` **solo se** quel ruolo ne ha una scritta in catalogo. Per gli altri l'anima nasce al primo avvio: vedi [Le anime](anime.md).

## Primo avvio

```bash
cd ~/Code/acme-shop      # dove hai innestato il bundle
./agents/dashboard.sh        # chi c'è
./agents/iterm.sh all        # una finestra iTerm2 per ciascuno, colori distinti
```

Oppure un agente solo, nel terminale corrente:

```bash
./agents/launch.sh giulia
```

Ogni agente all'avvio legge la sua anima e la sua identità, poi si ferma e aspetta. Non parte a fare analisi di sua iniziativa: è una regola scritta nelle anime, e serve a non bruciare contesto prima che tu abbia dato un ordine.

## Il primo giro di lavoro

```bash
# Il coordinatore assegna
./agents/msg.sh giulia marco "Progetta lo schema del catalogo ricambi. Spec in docs/specs/catalogo.md"

# Marco si segna al lavoro
./agents/setstatus.sh marco WORKING "Schema catalogo ricambi"

# Marco conferma di aver ricevuto
./agents/ack.sh msg-20260816-120000-giumar marco

# Quando ha finito, passa al tester
./agents/msg.sh marco davide "Schema pronto, migrazione in database/migrations. Verifica i vincoli."
./agents/setstatus.sh marco IDLE
```

`./agents/dashboard.sh` in qualsiasi momento mostra chi sta lavorando su cosa. `./agents/live-dashboard.sh` lo fa in refresh continuo, se vuoi tenerlo in una finestra dedicata.

## Il team cambia

```bash
./agents/hire.sh                      # interattivo
./agents/hire.sh ux-writer "Elena"    # diretto
```

Crea la cartella, aggiorna il manifest, registra inbox e coda. Da quel momento tutti gli script conoscono Elena. Se un passo fallisce, i precedenti vengono annullati: non resta mai mezzo agente.

## Problemi comuni

**`Errore: shared-context/TEAM.json non trovato`** — stai lanciando uno script fuori da un progetto configurato, oppure da una directory sbagliata. Gli script cercano `shared-context/` accanto ad `agents/`.

**`Errore: agente 'x' non riconosciuto`** — l'id non è nel manifest. Il messaggio elenca quelli validi. Ricorda che l'id è il nome normalizzato: `Niccolò` è `niccolo`.

**Il messaggio non arriva nella finestra** — `msg.sh` cerca la finestra iTerm2 per nome sessione, impostato da `iterm.sh`. Se hai aperto il terminale a mano, il nome non c'è. Il messaggio è comunque salvato in `shared-context/inbox/<id>/` e nel log: nessuna perdita.

**Vuoi lanciare gli script senza toccare iTerm2** — `OFFICE_NO_ITERM=1` salta la consegna e lascia solo log e inbox.
