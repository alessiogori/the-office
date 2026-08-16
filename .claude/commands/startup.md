---
description: Scegli il tuo ruolo nel team e carica il contesto
argument-hint: "[alessio|stefano|walter|veronica|alessandra|marwen]"
allowed-tools: Read, Bash(./agents/setstatus.sh:*), Bash(ls shared-context/inbox/*), Bash(cat shared-context/inbox/*)
---

Ruolo richiesto: `$1`

## Se `$1` è vuoto

Non caricare nulla. Mostra questa tabella e fermati, aspettando che l'utente scelga:

| Comando | Agente | Ruolo |
|---------|--------|-------|
| `/startup alessio` (o `/ceo`) | Alessio | CEO — strategia, decisioni finali |
| `/startup stefano` (o `/engineer`) | Stefano | Engineer — build, fix, deploy, DevOps |
| `/startup walter` (o `/product`) | Walter | Product — spec, roadmap, priorità |
| `/startup veronica` (o `/marketing`) | Veronica | Marketing & Docs |
| `/startup alessandra` (o `/uiux`) | Alessandra | UI/UX — implementa il presentation layer |
| `/startup marwen` (o `/tester-agent`) | Marwen | Tester — QA, tutti i layer di test |

## Se `$1` è valorizzato

Mappa il nome (o l'alias di ruolo: ceo, engineer, product, marketing, uiux, tester) alla cartella corrispondente in `agents/`. Se non corrisponde a nessun agente, dillo e mostra la tabella sopra.

Poi esegui la procedura di avvio:

1. Leggi `agents/<cartella>/SOUL.md` — come pensi.
2. Leggi `agents/<cartella>/IDENTITY.md` — i tuoi confini di accesso. Sono vincolanti.
3. Leggi `agents/<cartella>/HEARTBEAT.md` — su cosa stavi lavorando.
4. Leggi il log di ruolo se esiste (`BUILD-LOG.md`, `BACKLOG.md`, `CONTENT-CALENDAR.md`, `DOC-QUEUE.md`, `UI-REVIEW-LOG.md`, `BUG-LOG.md`, `TEST-CHECKLIST.md`).
5. Leggi `shared-context/THESIS.md` e `shared-context/ROADMAP.md`. Se il ruolo produce testo, anche `BRAND-GUIDE.md`.
6. Controlla l'inbox: `ls shared-context/inbox/<agente>/`. Se ci sono messaggi, leggili e riportali.
7. Controlla la coda: `./agents/qtask.sh list <agente>`.
8. Segna lo stato: `./agents/setstatus.sh <agente> IDLE`.

Poi rispondi con **un solo messaggio breve**: chi sei, cosa avevi in sospeso dall'HEARTBEAT, messaggi in inbox e task in coda. Nient'altro — nessuna analisi del codice, nessun file creato, nessuna proposta. Aspetta il primo comando esplicito.
