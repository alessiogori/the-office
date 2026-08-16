---
description: Scegli il tuo ruolo nel team e carica il contesto
argument-hint: "[nome o id dell'agente]"
allowed-tools: Read, Bash(./agents/setstatus.sh:*), Bash(./agents/qtask.sh list:*), Bash(ls shared-context/inbox/*), Bash(cat shared-context/inbox/*)
---

Agente richiesto: `$1`

Il team di questo progetto è descritto in `shared-context/TEAM.json`. Quello è l'elenco autorevole: non esiste una lista di ruoli cablata da nessuna parte, e ogni progetto ha un team diverso.

## Se `$1` è vuoto

Leggi `shared-context/TEAM.json` e mostra una tabella con una riga per persona — id, nome, etichetta del ruolo — più il comando per caricarla (`/startup <id>`). Poi fermati e aspetta che l'utente scelga. Non caricare nulla.

Se esistono anche comandi dedicati per alcuni di quei ruoli (`/ceo`, `/engineer`, `/product`, `/marketing`, `/uiux`, `/tester-agent`), segnalali nella riga corrispondente.

## Se `$1` è valorizzato

Risolvi `$1` contro `shared-context/TEAM.json`: accetta sia l'id (`stefano`) sia il nome proprio (`Stefano`), senza distinzione di maiuscole. Se non corrisponde a nessuno, dillo ed elenca gli id disponibili.

Da qui in avanti usa il campo `folder` della persona come radice dei suoi file, e il campo `log` per il nome del suo log di ruolo — può essere `null`, e allora quel passo si salta.

Procedura di avvio:

0. **Se `<folder>/SOUL.md` non esiste**, scrivilo prima di procedere: leggi `<folder>/ROLE-BRIEF.md`, `agents/_authoring/SOUL-AUTHORING.md`, `shared-context/THESIS.md` e `shared-context/BRAND-GUIDE.md`, scrivi l'anima calata su questo progetto, salvala, e dichiara all'utente che l'hai appena forgiata.
1. Leggi `<folder>/SOUL.md` — come pensi.
2. Leggi `<folder>/IDENTITY.md` — i tuoi confini di accesso. Sono vincolanti.
3. Leggi `<folder>/HEARTBEAT.md` — su cosa stavi lavorando.
4. Leggi il log di ruolo indicato dal campo `log`, se presente.
5. Leggi `shared-context/THESIS.md` e `shared-context/ROADMAP.md`. Se il ruolo produce testo destinato a essere letto da qualcuno, anche `BRAND-GUIDE.md`.
6. Controlla l'inbox: `ls shared-context/inbox/<id>/`. Se ci sono messaggi, leggili e riportali.
7. Controlla la coda: `./agents/qtask.sh list <id>`.
8. Segna lo stato: `./agents/setstatus.sh <id> IDLE`.

Poi rispondi con **un solo messaggio breve**: chi sei, cosa avevi in sospeso dall'HEARTBEAT, messaggi in inbox e task in coda. Nient'altro — nessuna analisi del codice, nessun file creato, nessuna proposta. Aspetta il primo comando esplicito.
