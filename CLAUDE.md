# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Cos'è questo repo

Due cose in un solo repo:

1. **Il sistema multi-agente** (`agents/`, `shared-context/`, `setup.sh`, `AGENTS.md`, `GEMINI.md`) — un template installabile in altri progetti. È il prodotto principale; `setup.sh` lo copia e lo personalizza altrove.
2. **`office-overlay/`** — app nativa Tauri 2 + Pixi.js che visualizza in tempo reale lo stato dei 6 agenti come stanza pixel-art. È l'unico codice compilabile del repo.

Il resto (`docs/`, `examples/`, `traffic-data/`) è documentazione e dati di esempio.

## Comandi

### office-overlay (Bun + Tauri + Vite)

```bash
cd office-overlay
bun install
bun run tauri dev      # dev completo (Rust + Vite su :1420)
bun run dev            # solo frontend Vite
bun run build          # tsc && vite build
bun run tauri build    # bundle nativo
npx tsc --noEmit       # typecheck isolato
```

Richiede Rust/Cargo e Xcode CLT su macOS. Non esiste una test suite: la verifica è visuale (`tauri dev` + `setstatus.sh` da un altro terminale).

### Sistema agenti

```bash
./agents/launch.sh <agente>            # avvia Claude Code col prompt di ruolo
./agents/iterm.sh <agente|all>         # apre finestre iTerm2 dedicate (una per agente)
./agents/setstatus.sh <agente> <WORKING|IDLE|STANDBY> ["task"]
./agents/with-status.sh <agente> "<task>" -- <comando>   # wrap: WORKING → comando → IDLE
./agents/msg.sh <mittente> <destinatario> "<testo>"
./agents/ack.sh <msg-id> <agente>
./agents/qtask.sh <add|done|list> <agente> [...]
./agents/dashboard.sh                  # snapshot stato + code
./agents/live-dashboard.sh             # dashboard in refresh continuo
./setup.sh                             # installa il sistema in un altro progetto (interattivo)
```

Agenti validi ovunque (lowercase, validati dagli script): `alessio`, `stefano`, `walter`, `veronica`, `alessandra`, `marwen`.

## Architettura

### Coordinamento via filesystem

Gli agenti non comunicano direttamente. Tutto passa da `shared-context/`:

| File | Scrittore | Formato |
|------|-----------|---------|
| `AGENT-STATUS.json` | `setstatus.sh` | mappa `agente → {status, task, ts}`, riscritta interamente |
| `MSG-LOG.jsonl` | `msg.sh`, `ack.sh` | append-only, eventi `SENT` / `ACK` sulla stessa timeline |
| `inbox/<agente>/` | `msg.sh` | messaggi recapitati |
| `queues/<agente>.json` | `qtask.sh` | array di task pendenti |

Regole invarianti: `MSG-LOG.jsonl` non viene **mai** riscritto, solo appeso. Gli script fanno la mutazione JSON via `python3 -c` inline (dipendenza implicita: Python 3). `msg.sh`/`ack.sh` recapitano il messaggio nella finestra iTerm2 dell'agente via AppleScript, cercandola per nome sessione (`Stefano`, `Walter`, …) — nomi impostati da `iterm.sh`. Se cambi i nomi in uno script devi cambiarli in tutti e tre.

### office-overlay: il flusso dei dati

```
setstatus.sh / msg.sh
    ↓ scrive shared-context/*
watcher Rust (notify crate, src-tauri/src/lib.rs)
    ↓ emit "agent-status" / "agent-msg"
main.ts (listen)
    ↓
AgentSprite.setState() → Pixi render
```

- **`src-tauri/src/lib.rs`** — risolve `shared-context/` risalendo fino a 5 livelli dalla cwd, override con `OFFICE_SHARED_DIR` / `OFFICE_STATUS_FILE` / `OFFICE_MSG_LOG`. Due watcher separati: status (rilegge il JSON intero) e msg-log (tail incrementale con offset, legge solo le righe nuove). Espone un solo comando, `get_status`, usato per il caricamento iniziale.
- **`src/agents.ts`** — sorgente unica di verità per id, nomi, ruoli e colori degli agenti. Aggiungere/rinominare un agente parte da qui **e** dalla validazione in ogni script bash.
- **`src/room.ts`** — costruisce la stanza (tile, scrivanie, decorazioni) e restituisce gli anchor (`desks`, `monitors`, `steamAnchor`, `windowGlow`) usati da main.ts.
- **`src/agent.ts`** — sprite procedurale per agente: animazioni per stato, wander in IDLE, badge task, flash sui messaggi.
- **`src/atmosphere.ts`** / **`src/daynight.ts`** — vapore, glow pulsante, tinta ambientale in base all'ora.
- La finestra è borderless, trasparente, always-on-top (`src-tauri/tauri.conf.json`); drag handle e context menu sono HTML in `index.html`, non Pixi.

Gli sprite sono disegnati proceduralmente con `Graphics`, senza spritesheet: `src/assets/` contiene solo le icone del template Tauri. Il render non dipende da asset esterni.

### Hook di stato automatico

`agents/claude-hooks/pre-tool.sh` (PreToolUse) e `stop.sh` (Stop) chiamano `setstatus.sh` per marcare l'agente WORKING/IDLE senza intervento manuale. Richiedono `OFFICE_AGENT=<agente>` nell'ambiente della sessione; senza quella var escono silenziosamente. Non sono registrati in `.claude/settings.local.json` — vanno aggiunti a mano al `settings.json` del progetto che li usa.

### Configurazioni parallele

`CLAUDE.md`, `AGENTS.md` (Cursor/Copilot/Windsurf/Codex) e `GEMINI.md` descrivono lo **stesso** sistema per tool diversi. Una modifica ai ruoli o ai confini di accesso va replicata in tutti e tre, e nei template di `setup.sh`.

---

# Il sistema multi-agente

## Agent Roles

### CEO (Alessio)
- **Role:** Strategic oversight, final decisions, resource allocation
- **Access:** Everything. No restrictions.
- **Config:** agents/ceo/

### Engineer (Stefano)
- **Role:** Build features, fix bugs, deploy, DevOps (CI/CD, monitoring, environments), security hardening, API documentation
- **Access:** Can read/write code, scripts, configs. Cannot touch marketing content or product strategy docs.
- **Config:** agents/engineer/

### Product (Walter)
- **Role:** Strategy, roadmap, specs, user research, prioritization, analytics interpretation, A/B test design
- **Access:** Can read/write product docs, specs, roadmap. Can read analytics. Cannot write code directly.
- **Config:** agents/product/

### Marketing & Documentation (Veronica)
- **Role:** Dual mode — Marketing (content, brand, growth, social) when active campaigns; Documentation (user guides, changelogs, internal docs, landing page copy) otherwise. Same skill, two directions.
- **Access:** Can read/write marketing/ and docs/ folders. Can read all code (for documentation context). Cannot touch code or product strategy docs.
- **Config:** agents/marketing/

### UI/UX Specialist (Alessandra)
- **Role:** Implements the presentation layer: layout, design system ownership, accessibility, responsiveness, UX polish, microcopy (with Veronica), landing page implementation. Designs AND builds — not just reviews.
- **Access:** Can read all code. Can modify frontend (views, CSS, JS, static assets). Can run Playwright as self-check on own changes. Cannot modify backend or own/extend the automated Playwright test suite (that's Marwen's).
- **Config:** agents/uiux/

### Tester (Marwen)
- **Role:** QA single source of truth. All test layers: unit, integration, E2E (Playwright), performance (Lighthouse), security (OWASP), accessibility (axe-core). Bug reporting, quality enforcement, deploy gate.
- **Access:** Can read all code. Can write/modify tests (tests/**) and test config. Cannot edit app source code or frontend code (that's Alessandra's).
- **Config:** agents/tester/

## Pipeline

```
Walter (spec) → Stefano (build) → Alessandra (UI/UX) → Marwen (QA) → produzione
```

Niente va in produzione senza passare da Alessandra e Marwen.

## File per agente

Ogni cartella `agents/<ruolo>/` contiene `SOUL.md` (come pensa), `IDENTITY.md` (confini di accesso), `HEARTBEAT.md` (stato corrente) più un log di ruolo: `BUILD-LOG.md`, `BACKLOG.md`, `CONTENT-CALENDAR.md` + `DOC-QUEUE.md`, `UI-REVIEW-LOG.md`, `BUG-LOG.md` + `TEST-CHECKLIST.md`.

## Shared Context
Letto da tutti gli agenti: `shared-context/THESIS.md` (visione), `ROADMAP.md`, `BRAND-GUIDE.md` (voce e tono).

## Session Tracking
Un file al giorno: `docs/sessions/YYYY-MM-DD-session.md`. Ogni agente aggiorna la propria sezione.

## Rules
1. Agents stay in their lane. No crossing access boundaries.
2. Disagreements are good. The tester should challenge the engineer. The product lead should push back on the CEO.
3. Every agent reads their SOUL.md and IDENTITY.md at the start of every session.
4. HEARTBEAT.md gets updated at the end of every session.
5. When in doubt, check shared-context/THESIS.md for alignment.

## Slash Commands

Definiti in `.claude/commands/`. Valgono solo dentro una sessione Claude Code già avviata; per aprire un terminale nuovo per un agente usa `./agents/launch.sh <agente>` o `./agents/iterm.sh <agente>`.

| Comando | Cosa fa |
|---------|---------|
| `/startup [agente]` | Senza argomento mostra i ruoli; con argomento carica quel ruolo |
| `/ceo` `/engineer` `/product` `/marketing` `/uiux` `/tester-agent` | Caricano direttamente il ruolo |
| `/session` | Aggiorna la tua sezione in `docs/sessions/<data>-session.md` |
| `/wrap-up` | Chiusura: HEARTBEAT, log di ruolo, sessione, ACK inbox, stato STANDBY |

Ogni comando di ruolo segue lo stesso schema: SOUL → IDENTITY → HEARTBEAT → log di ruolo → shared-context → inbox → coda → `setstatus.sh <agente> IDLE`, poi un solo messaggio di ready e stop. Se aggiungi o rinomini un agente vanno aggiornati insieme: il comando, `src/agents.ts`, la validazione in ogni script bash, `AGENTS.md` e `GEMINI.md`.

`/wrap-up` e `/session` scrivono su un file condiviso da più sessioni: modificano **solo** la sezione dell'agente corrente, mai il file intero.
