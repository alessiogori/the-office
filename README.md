# The Office

Un sistema multi-agente per gestire progetti con AI coding tools. Funziona con Claude Code, Cursor, Copilot, Windsurf, Gemini CLI, Codex, Devin e Replit. Ogni agente ha un'anima, un'identità e confini precisi. Aggiungilo a qualsiasi progetto e inizia a spedire.

## 6 agenti. 6 terminali. 1 contesto condiviso. Zero standup.

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

## Gli agenti

| Agente | Nome | Ruolo | File di log |
|--------|------|-------|-------------|
| CEO | Alessio | Strategia, decisioni finali, override | — |
| Engineer | Stefano | Build, bug fix, deploy | `BUILD-LOG.md` |
| Product | Walter | Specs, roadmap, priorità | `BACKLOG.md` |
| Marketing | Veronica | Contenuti, brand, crescita | `CONTENT-CALENDAR.md` |
| UI/UX Specialist | Alessandra | Review visivo, Playwright headless, standard di mercato | `UI-REVIEW-LOG.md` |
| Tester | Marwen | QA, bug reporting, quality enforcement | `BUG-LOG.md` |

## Cosa ti serve

Queste cartelle vanno nel tuo progetto:

| Cartella/File | Cosa fa |
|---------------|---------|
| `agents/` | Le definizioni dei 6 agenti (SOUL.md, IDENTITY.md, HEARTBEAT.md ciascuno) |
| `shared-context/` | THESIS.md, ROADMAP.md, BRAND-GUIDE.md — letti da tutti gli agenti |
| `CLAUDE.md` | Regole e ruoli degli agenti (aggiungilo al tuo esistente) |

## Quick Start

### Opzione 1: Aggiungi a un progetto esistente (consigliato)

Hai già un progetto con il suo CLAUDE.md? Aggiungi solo il sistema agenti.

**Step 1:** Aggiungi le regole agenti al `CLAUDE.md` del tuo progetto:

```markdown
## Sistema Multi-Agente

Questo progetto usa un sistema multi-agente. Ogni agente ha ruolo, personalità e confini di accesso definiti.

### Ruoli
- **CEO (Alessio)** — supervisione strategica, decisioni finali. Accesso: tutto. Config: agents/ceo/
- **Engineer (Stefano)** — build, bug fix, deploy. Accesso: solo codice. Config: agents/engineer/
- **Product (Walter)** — strategia, roadmap, specs. Accesso: solo docs prodotto. Config: agents/product/
- **Marketing (Veronica)** — contenuti, brand, crescita. Accesso: solo marketing/. Config: agents/marketing/
- **UI/UX Specialist (Alessandra)** — review visivo, Playwright headless, standard di mercato. Accesso: legge frontend, scrive UI-REVIEW-LOG.md. Config: agents/uiux/
- **Tester (Marwen)** — QA, bug reporting. Accesso: legge tutto, scrive solo report. Config: agents/tester/

### Regole
1. Ogni agente rimane nel suo dominio.
2. Ogni agente legge SOUL.md e IDENTITY.md all'avvio.
3. HEARTBEAT.md viene aggiornato a fine sessione.
4. In caso di dubbio, controlla shared-context/THESIS.md.
```

**Step 2:** Scarica i file agente:
1. Vai su [questo repo su GitHub](https://github.com/alessiogori/the-office)
2. Clicca il bottone verde **Code** → **Download ZIP**
3. Decomprimi e copia queste due cartelle nel tuo progetto:
   - `agents/` → `tuo-progetto/agents/`
   - `shared-context/` → `tuo-progetto/shared-context/`

**Step 3:** Apri la cartella `shared-context/` e personalizza i file:
- `THESIS.md` — sostituisci con la tua visione e i tuoi principi
- `ROADMAP.md` — sostituisci con il tuo roadmap attuale
- `BRAND-GUIDE.md` — sostituisci con la tua voce, tono e stile

**Step 4:** Apri 6 terminali e avvia ogni agente:

```bash
# Terminale 1: CEO
claude "Sei Alessio, il CEO. Leggi agents/ceo/SOUL.md e agents/ceo/IDENTITY.md. Controlla i HEARTBEAT.md di tutti gli agenti e imposta le priorità di oggi."

# Terminale 2: Engineer
claude "Sei Stefano, l'Engineer. Leggi agents/engineer/SOUL.md e agents/engineer/IDENTITY.md. Controlla BUILD-LOG.md e inizia a costruire."

# Terminale 3: Product
claude "Sei Walter, il Product Lead. Leggi agents/product/SOUL.md e agents/product/IDENTITY.md. Controlla BACKLOG.md e affina la spec prioritaria."

# Terminale 4: Marketing
claude "Sei Veronica, il Marketing Lead. Leggi agents/marketing/SOUL.md e agents/marketing/IDENTITY.md. Controlla CONTENT-CALENDAR.md e scrivi il prossimo post."

# Terminale 5: UI/UX Specialist
claude "Sei Alessandra, la UI/UX Specialist. Leggi agents/uiux/SOUL.md e agents/uiux/IDENTITY.md. Controlla cosa ha spedito Stefano e avvia Playwright headless su quelle pagine."

# Terminale 6: Tester
claude "Sei Marwen, il Tester. Leggi agents/tester/SOUL.md e agents/tester/IDENTITY.md. Controlla cosa ha passato Alessandra e inizia i test funzionali."
```

Fatto. Ogni agente carica la sua anima e rimane nel suo dominio.

### Opzione 2: Parti da zero con gli agenti già integrati

Stai iniziando un nuovo progetto? Clona il repo e personalizza da lì:

```bash
git clone https://github.com/alessiogori/the-office.git mio-progetto
cd mio-progetto

# Modifica i file in shared-context/ per il tuo progetto
# Poi apri 6 terminali e lancia gli agenti (vedi Step 4 sopra)
```

## Struttura del progetto

```
tuo-progetto/
├── CLAUDE.md                    ← la tua config esistente + regole agenti
├── agents/
│   ├── ceo/                     ← Alessio — supervisione strategica
│   │   ├── SOUL.md
│   │   ├── IDENTITY.md
│   │   └── HEARTBEAT.md
│   ├── engineer/                ← Stefano — build, fix, deploy
│   │   ├── SOUL.md
│   │   ├── IDENTITY.md
│   │   ├── HEARTBEAT.md
│   │   └── BUILD-LOG.md
│   ├── product/                 ← Walter — strategia, roadmap, specs
│   │   ├── SOUL.md
│   │   ├── IDENTITY.md
│   │   ├── HEARTBEAT.md
│   │   └── BACKLOG.md
│   ├── marketing/               ← Veronica — contenuti, brand, crescita
│   │   ├── SOUL.md
│   │   ├── IDENTITY.md
│   │   ├── HEARTBEAT.md
│   │   └── CONTENT-CALENDAR.md
│   ├── uiux/                    ← Alessandra — review visivo, Playwright, standard di mercato
│   │   ├── SOUL.md
│   │   ├── IDENTITY.md
│   │   ├── HEARTBEAT.md
│   │   └── UI-REVIEW-LOG.md
│   └── tester/                  ← Marwen — QA, rompe tutto prima degli utenti
│       ├── SOUL.md
│       ├── IDENTITY.md
│       ├── HEARTBEAT.md
│       ├── BUG-LOG.md
│       └── TEST-CHECKLIST.md
└── shared-context/
    ├── THESIS.md                ← cosa crediamo
    ├── ROADMAP.md               ← dove stiamo andando
    └── BRAND-GUIDE.md           ← come suoniamo
```

**Incluso in questo repo (non necessario nel tuo progetto):**

```
the-office/
├── AGENTS.md                    ← config per Cursor, Copilot, Windsurf, ecc.
├── GEMINI.md                    ← config per Gemini CLI
└── examples/
    ├── product/sample-prd.md
    ├── marketing/sample-content-calendar.md
    └── engineering/sample-build-log.md
```

## Slash Commands

| Comando | Cosa fa |
|---------|---------|
| `/startup` | Scegli il tuo ruolo e carica il contesto |
| `/engineer` | Passa all'agente Stefano |
| `/product` | Passa all'agente Walter |
| `/marketing` | Passa all'agente Veronica |
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

## Licenza

MIT — usalo come vuoi.
