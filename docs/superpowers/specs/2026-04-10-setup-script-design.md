# Setup Script — Design Spec
**Data:** 2026-04-10

## Obiettivo
Uno script `setup.sh` che guida l'utente nel configurare il sistema multi-agente di `the-office` per un nuovo progetto. Raccoglie le informazioni chiave, genera i file personalizzati e copia tutto nella directory target.

## Approccio scelto
Shell script puro (bash). Nessuna dipendenza esterna. I file `shared-context/` vengono generati con struttura base e valori interpolati — l'utente li raffina successivamente con Claude Code.

## Flusso di esecuzione

```
1. Messaggio di benvenuto + spiegazione breve
2. Raccolta input con default mostrati
3. Validazione directory di destinazione (crea se non esiste, con conferma)
4. Generazione file nella directory target
5. Messaggio finale con prossimi passi
```

## Input raccolti

| Domanda | Default |
|---|---|
| Directory di destinazione | obbligatoria |
| Nome del progetto | `my-project` |
| Descrizione breve (1 riga) | vuoto |
| Tech stack | vuoto |
| Nome brand/azienda | = nome progetto |
| Nome CEO | `Alessio` |
| Nome Engineer | `Stefano` |
| Nome Product | `Walter` |
| Nome Marketing | `Veronica` |
| Nome UI/UX | `Alessandra` |
| Nome Tester | `Marwen` |

## File generati nella directory target

### Root
- `CLAUDE.md` — overview con nome progetto e nomi agenti aggiornati
- `AGENTS.md` — istruzioni multi-platform con nomi agenti aggiornati
- `GEMINI.md` — copiato invariato
- `.gitignore` — copiato invariato

### `agents/`
- `msg.sh` — destinatari aggiornati con i nomi scelti
- Per ogni agente (`ceo`, `engineer`, `product`, `marketing`, `uiux`, `tester`):
  - `SOUL.md` — copiato con nomi agenti sostituiti via `sed`
  - `IDENTITY.md` — copiato con nomi agenti sostituiti via `sed`
  - `HEARTBEAT.md` — copiato invariato
  - File di log specifico del ruolo (`BUILD-LOG.md`, `BACKLOG.md`, `CONTENT-CALENDAR.md`, `UI-REVIEW-LOG.md`, `BUG-LOG.md`, `TEST-CHECKLIST.md`) — copiati invariati

### `shared-context/`
- `THESIS.md` — struttura base con nome progetto e descrizione interpolati
- `ROADMAP.md` — struttura base con tech stack interpolato
- `BRAND-GUIDE.md` — struttura base con nome brand interpolato

### `examples/`
- Copiata invariata

## Dettagli implementativi

### Pattern input con default
```bash
read -p "Nome CEO [Alessio]: " CEO_NAME
CEO_NAME=${CEO_NAME:-Alessio}
```

### Pattern sostituzione nomi nei SOUL.md / IDENTITY.md
```bash
sed "s/Stefano/$ENGINEER_NAME/g" agents/engineer/SOUL.md > "$TARGET/agents/engineer/SOUL.md"
```

### Pattern generazione shared-context
```bash
cat > "$TARGET/shared-context/THESIS.md" << EOF
# Thesis — What We Believe
...contenuto con $PROJECT_NAME e $DESCRIPTION interpolati...
EOF
```

### Validazione directory target
Se non esiste: chiede conferma prima di crearla con `mkdir -p`.
Se esiste e non è vuota: avvisa l'utente ma procede (non blocca).

## Prossimi passi suggeriti allo script al termine
1. Aprire la directory con Claude Code
2. Raffinare `shared-context/THESIS.md` con la visione reale del progetto
3. Aggiornare `shared-context/ROADMAP.md` con le priorità attuali
4. Lanciare gli agenti
