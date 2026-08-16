---
description: Aggiorna la tua sezione nel file di sessione condiviso
allowed-tools: Read, Write, Edit, Bash(date:*), Bash(ls docs/sessions/*), Bash(mkdir -p docs/sessions)
---

Aggiorna la tua sezione nel file di sessione di oggi.

**Prerequisito:** devi già aver caricato un ruolo (`/startup`, `/engineer`, `/product`, …). Se non sai chi sei, fermati e chiedilo — non indovinare.

## Procedura

1. Ricava la data di oggi con `date "+%Y-%m-%d"`. Il file è `docs/sessions/<data>-session.md`.
2. Se la directory non esiste: `mkdir -p docs/sessions`.
3. Se il file non esiste, crealo con l'intestazione e **tutte e sei** le sezioni agente vuote, in quest'ordine: Alessio (CEO), Stefano (Engineer), Walter (Product), Veronica (Marketing & Docs), Alessandra (UI/UX), Marwen (Tester).

```markdown
# Sessione <data>

## Alessio — CEO
_(nessun aggiornamento)_

## Stefano — Engineer
_(nessun aggiornamento)_

...
```

4. Modifica **solo la tua sezione**. Non toccare quelle degli altri agenti nemmeno per riformattarle: il file è condiviso e altre sessioni ci scrivono in parallelo. Usa Edit sulla tua sezione, mai Write sull'intero file se esiste già.
5. Nella tua sezione scrivi, in forma sintetica:
   - **Fatto** — cosa hai completato in questa sessione
   - **In corso** — cosa è a metà
   - **Bloccato** — cosa ti manca e da chi dipende (con il nome dell'agente)
   - **Passato a** — cosa hai consegnato e a chi (se hai mandato un `msg.sh`, cita l'ID)

Fatti concreti, non riassunti generici. "Fix BUG-042, deployato in staging" vale, "lavorato sul backend" no.

6. Riporta all'utente in due righe cosa hai scritto.

Se `$ARGUMENTS` contiene del testo, usalo come contenuto dell'aggiornamento invece di dedurlo dalla conversazione.
