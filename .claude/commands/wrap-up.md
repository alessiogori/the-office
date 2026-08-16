---
description: Chiusura di giornata — aggiorna HEARTBEAT, log di ruolo e stato
allowed-tools: Read, Write, Edit, Bash(date:*), Bash(./agents/setstatus.sh:*), Bash(./agents/qtask.sh list:*), Bash(ls shared-context/inbox/*), Bash(mkdir -p docs/sessions)
---

Chiudi la sessione. Esegui i passi nell'ordine, senza saltarne nessuno.

**Prerequisito:** devi già aver caricato un ruolo. Se non sai chi sei, fermati e chiedilo.

## 1. HEARTBEAT.md

Aggiorna `agents/<tuo-ruolo>/HEARTBEAT.md`. Mantieni la struttura di sezioni già presente nel file — sostituisci il contenuto, non il formato. Compila la data con `date "+%Y-%m-%d"`.

L'HEARTBEAT è il tuo unico punto di ripresa alla sessione successiva: se una cosa non è scritta lì, alla prossima sessione non esiste.

## 2. Log di ruolo

Aggiungi una voce al tuo log, se hai qualcosa da registrare:

| Ruolo | File |
|-------|------|
| Stefano | `agents/engineer/BUILD-LOG.md` |
| Walter | `agents/product/BACKLOG.md` |
| Veronica | `agents/marketing/CONTENT-CALENDAR.md` o `DOC-QUEUE.md` |
| Alessandra | `agents/uiux/UI-REVIEW-LOG.md` |
| Marwen | `agents/tester/BUG-LOG.md` |
| Alessio | nessun log dedicato — usa l'HEARTBEAT |

## 3. File di sessione

Aggiorna la tua sezione in `docs/sessions/<data>-session.md` seguendo la procedura di `/session`. Solo la tua sezione.

## 4. Verifiche finali

- Inbox svuotata: `ls shared-context/inbox/<agente>/`. Ogni messaggio ricevuto va confermato con `./agents/ack.sh <msg-id> <agente>` prima di chiudere.
- Consegne notificate: se hai finito qualcosa che sblocca un collega, mandagli un `./agents/msg.sh <tu> <collega> "<testo>"` adesso.
- Coda: `./agents/qtask.sh list <agente>` — chiudi con `qtask.sh done` i task completati.
- Stato: `./agents/setstatus.sh <agente> STANDBY`.

## 5. Riepilogo

Chiudi con un riepilogo di massimo 5 righe: cosa hai fatto, cosa resta aperto, da chi dipendi. Se sei Alessio, aggiungi lo stato del team leggendo gli HEARTBEAT degli altri cinque agenti.
