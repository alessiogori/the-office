# The Office

Un sistema multi-agente per gestire progetti con AI coding tools. Funziona con Claude Code, Cursor, Copilot, Windsurf, Gemini CLI, Codex, Devin e Replit. Scegli quante persone ti servono e che ruolo hanno, da un catalogo di 36 figure. Ogni agente ha un'anima, un'identità e confini precisi.

## Il tuo team. I tuoi terminali. 1 contesto condiviso. Zero standup.

> Alessio dà la direzione. Walter gestisce il roadmap. Veronica scrive i contenuti. Stefano costruisce. Alessandra giudica ogni pagina senza pietà. Marwen rompe tutto prima che lo facciano gli utenti. Si coordinano tramite file, non riunioni.

---

## Come funziona

Ogni agente ha tre file fondamentali:

- **SOUL.md** — come pensa, cosa valorizza, cosa si rifiuta di fare
- **IDENTITY.md** — ruolo, confini di accesso, con chi lavora
- **HEARTBEAT.md** — su cosa sta lavorando adesso, aggiornato ogni sessione

Gli agenti non possono accedere ai domini altrui. Stefano non tocca il marketing. Walter non scrive codice. Alessandra legge il frontend ma non lo modifica. Marwen legge tutto ma non edita niente. Gli stessi confini che imporrestia un team reale.

## Il pipeline

```
Walter (Product) → spec
        ↓
Stefano (Engineer) → build
        ↓
Alessandra (UI/UX) → Playwright headless + ricerca mercato → APPROVED / REJECTED
        ↓
Marwen (Tester) → QA funzionale
        ↓
Produzione
```

Niente va in produzione senza passare da Alessandra e Marwen.

## Il team di default

Il wizard non impone nessun team. Questo è quello che gira in questo repo, e resta un buon punto di partenza per un progetto software:

| Nome | Ruolo | File di log |
|------|-------|-------------|
| Alessio | CEO / Founder | — |
| Stefano | Engineer (full-stack) | `BUILD-LOG.md` |
| Walter | Product Manager | `BACKLOG.md` |
| Veronica | Marketing & Documentation | `CONTENT-CALENDAR.md` |
| Alessandra | UI/UX Specialist | `UI-REVIEW-LOG.md` |
| Marwen | Tester / QA | `BUG-LOG.md` |

Un team può essere anche molto diverso: un solo Project Manager e due backend, oppure un CEO con marketing, SEO e social e nessuno sviluppatore. Chi c'è è scritto in `shared-context/TEAM.json`, e tutti gli script leggono da lì.

## Quick Start

```bash
git clone --recurse-submodules https://github.com/alessiogori/the-office.git
cd the-office
./setup.sh
```

Il wizard chiede, in quest'ordine:

1. Dove installare, nome del progetto, descrizione, stack, brand
2. **Quante persone** servono nel team (1-12)
3. **Chi coordina** — obbligatorio, si sceglie tra CEO, Project Manager, Tech Lead, Delivery Lead e Chief of Staff
4. Il ruolo di ogni altra persona, cercandolo nel catalogo
5. Il nome di ognuna

Poi mostra il team e chiede conferma. Niente viene scritto prima di quel sì.

Richiede [gum](https://github.com/charmbracelet/gum) per le schermate: se manca, il wizard te lo dice e propone il comando di installazione.

### Senza TUI, o per setup riproducibili

```bash
./setup.sh --config team.json --target ~/Code/mio-progetto
```

```json
{
  "project": { "name": "acme", "description": "…", "stack": "Laravel, Vue", "brand": "Acme" },
  "team": [
    { "role": "pm",       "name": "Giulia" },
    { "role": "backend",  "name": "Marco" },
    { "role": "backend",  "name": "Luca" },
    { "role": "tester",   "name": "Davide" }
  ]
}
```

La prima persona deve avere un ruolo di coordinamento. Due persone possono avere lo stesso ruolo: si distinguono per nome. `--save-config` esporta le scelte di una sessione interattiva, per rifarla identica altrove.

### Avviare gli agenti

```bash
./agents/iterm.sh all        # una finestra iTerm2 per ciascuno, colori distinti
./agents/launch.sh <id>      # una sola persona nel terminale corrente
./agents/dashboard.sh        # chi c'è, chi lavora, su cosa
```

## Aggiungere una persona

Un team cambia. `setup.sh` serve una volta sola, `hire.sh` tutte le altre:

```bash
./agents/hire.sh                      # interattivo: ruolo dal catalogo, poi nome
./agents/hire.sh security "Niccolò"   # diretto, senza gum
```

Crea la cartella, aggiorna il manifest, registra inbox e coda. Se un passo fallisce, i precedenti vengono annullati: non resta mai un mezzo agente.

Rimuovere una persona non è previsto: cancellare log, inbox e messaggi inviati è una decisione che merita più di un comando.

## Il catalogo

36 figure in sette categorie, in `catalog/roles.json`:

| Categoria | Figure |
|-----------|--------|
| Coordinamento | CEO, Project Manager, Tech Lead, Delivery Lead, Chief of Staff |
| Prodotto e ricerca | Product Manager, User Researcher, Market Researcher, Business Analyst, Data Analyst |
| Design | UI/UX, Graphic Designer, UX Writer, Motion Designer |
| Engineering | Full-stack, Backend, Frontend, Mobile, DevOps, Data Engineer, ML Engineer, Architect, DBA |
| Qualità e sicurezza | Tester, Automation & Performance, Security, Accessibility |
| Go-to-market | Marketing & Docs, Copywriter, SEO, Social, Sales, Support |
| Operations | Technical Writer, Legal & Compliance, Finance |

Ogni voce porta missione, cosa può e cosa **non** può fare, con chi collabora, e un **attrito dichiarato**: contro chi spinge e su cosa. Quel campo è ciò che impedisce a un agente di diventare un sì-uomo.

Serve una figura che non c'è? Aggiungi una voce al JSON: `hire.sh` la vede subito, senza toccare codice.

## Le anime

Sei ruoli hanno un `SOUL.md` scritto a mano in `catalog/souls/`. Gli altri trenta no, ed è voluto: quando avvii per la prima volta un agente senza anima, l'anima viene **scritta in quel momento**, leggendo il suo `ROLE-BRIEF.md`, la THESIS e la BRAND-GUIDE del tuo progetto.

Un tester in un sistema di pagamenti e un tester in un blog non hanno le stesse ossessioni. Scrivere l'anima a runtime invece che nel catalogo è ciò che permette la differenza.

## Comunicazione tra agenti

Gli agenti si mandano messaggi tramite due script in `agents/`:

### Inviare un messaggio

```bash
./agents/msg.sh <mittente> <destinatario> "<testo>"
# es: ./agents/msg.sh stefano walter "Modulo pagamenti pronto. Rivedi docs/payments.md."
```

Ogni agente deve identificarsi come mittente. Gli id validi sono quelli in `shared-context/TEAM.json`: se ne sbagli uno, lo script te li elenca. Il messaggio che arriva in iTerm2:

```
--- MESSAGGIO IN ARRIVO ---
Da:        Stefano
A:         Walter
Timestamp: 2026-04-12T15:30:42
ID:        msg-20260412-153042-stewa

Modulo pagamenti pronto. Rivedi docs/payments.md.

Per rispondere:           ./agents/msg.sh stefano walter "<tua risposta>"
Per confermare ricezione: ./agents/ack.sh msg-20260412-153042-stewa walter
---------------------------
```

### Confermare la ricezione

```bash
./agents/ack.sh <msg-id> <agente-corrente>
# es: ./agents/ack.sh msg-20260412-153042-stewa walter
```

Scrive un evento `ACK` nel log e notifica il mittente originale.

### Log messaggi

Tutti i messaggi vengono archiviati in `shared-context/MSG-LOG.jsonl`. Ogni riga è un evento JSON:

```jsonl
{"id":"msg-...","type":"SENT","ts":"...","from":"Stefano","to":"Walter","msg":"..."}
{"id":"msg-...","type":"ACK","ts":"...","ack_by":"Walter","original_from":"Stefano","original_to":"Walter"}
```

Il log è append-only: nessuna riga viene mai riscritta. `SENT` e `ACK` sono eventi separati sulla stessa timeline. Puoi interrogarlo con `grep` o `jq`.

---

## Struttura del progetto

```
tuo-progetto/
├── CLAUDE.md                    ← la tua config esistente + regole agenti
├── agents/
│   ├── lib/
│   │   ├── team.sh              ← chi c'è nel team (usata da ogni script)
│   │   ├── roster.sh            ← chi potrebbe esserci (catalogo, generazione)
│   │   └── tui.sh               ← schermate gum
│   ├── msg.sh                   ← invia messaggi strutturati tra agenti
│   ├── ack.sh                   ← conferma ricezione di un messaggio
│   ├── hire.sh                  ← aggiunge una persona al team
│   ├── iterm.sh                 ← apre una finestra per agente
│   ├── launch.sh                ← avvia un agente
│   ├── dashboard.sh             ← stato del team
│   ├── _authoring/
│   │   └── SOUL-AUTHORING.md    ← come si scrive un'anima
│   └── <persona>/               ← una cartella per persona, non per ruolo
│       ├── SOUL.md              ← come pensa (scritta al primo avvio se manca)
│       ├── IDENTITY.md          ← confini di accesso, generato dai dati
│       ├── HEARTBEAT.md         ← a che punto è
│       ├── ROLE-BRIEF.md        ← i dati del suo ruolo
│       └── <LOG>.md             ← log di ruolo, se previsto
├── catalog/
│   ├── roles.json               ← le 36 figure disponibili
│   └── templates/               ← template di heartbeat e log
└── shared-context/
    ├── TEAM.json                ← chi c'è: la sorgente di verità
    ├── THESIS.md                ← cosa crediamo
    ├── ROADMAP.md               ← dove stiamo andando
    ├── BRAND-GUIDE.md           ← come suoniamo
    └── MSG-LOG.jsonl            ← archivio completo messaggi inter-agente
```

`CLAUDE.md`, `AGENTS.md` e `GEMINI.md` vengono generati dal wizard a partire dal tuo team, quindi elencano le persone che hai scelto davvero.

**Incluso in questo repo (non copiato nei progetti):**

```
the-office/
├── setup.sh                     ← il wizard
├── .claude/commands/            ← slash command, legati al team di questo repo
├── catalog/souls/               ← le sei anime scritte a mano
├── exports/                     ← i bundle generati (gitignored)
├── tests/                       ← suite bats
└── examples/
```

## Slash Commands

| Comando | Cosa fa |
|---------|---------|
| `/startup` | Scegli il tuo ruolo e carica il contesto |
| `/ceo` | Passa all'agente Alessio |
| `/engineer` | Passa all'agente Stefano |
| `/product` | Passa all'agente Walter |
| `/marketing` | Passa all'agente Veronica |
| `/uiux` | Passa all'agente Alessandra |
| `/tester-agent` | Passa all'agente Marwen |
| `/session` | Aggiorna la tua sezione nel file di sessione condiviso |
| `/wrap-up` | Riepilogo di fine giornata cross-agente |

## Il conflitto è la feature

Alessandra rimanda le pagine indietro a Stefano perché fanno schifo — con prove e soluzioni concrete. Marwen apre bug contro l'engineer senza sconti. Walter rifiuta le feature che non sono sul roadmap. Alessio fa override di tutti perché è il CEO.

Non è un problema. È come funzionano i team veri. La tensione produce output migliore.

## Altri AI tool

Questo repo include file di configurazione per altri tool:
- `AGENTS.md` — funziona con Cursor, Copilot, Windsurf, Codex, Devin, Replit
- `GEMINI.md` — funziona con Gemini CLI

Copia il file rilevante nel tuo progetto se usi quei tool.

## Documentazione

Guide complete in [`docs/`](docs/README.md):

| Documento | Contenuto |
|-----------|-----------|
| [Guida introduttiva](docs/getting-started.md) | Dal clone al primo agente avviato |
| [Catalogo dei ruoli](docs/catalogo-ruoli.md) | Le 36 figure, con confini e attriti |
| [Comandi](docs/comandi.md) | Reference di tutti gli script |
| [Architettura](docs/architettura.md) | Come è fatto, e perché così |
| [Le anime](docs/anime.md) | Cos'è un SOUL.md e come si scrive |
| [Estendere il catalogo](docs/estendere-il-catalogo.md) | Aggiungere una figura |
| [Testing](docs/testing.md) | La suite bats |

## Licenza

MIT — usalo come vuoi.
