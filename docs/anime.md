# Le anime

`SOUL.md` è il file che dice a un agente **come pensare**. È la parte del sistema che non si può generare da una tabella.

## Anima e identità sono due cose diverse

| | `IDENTITY.md` | `SOUL.md` |
|---|---|---|
| Risponde a | Cosa posso toccare? | Come ragiono? |
| Origine | Generato dai dati del catalogo | Scritto |
| Contenuto | Confini `can`/`cannot`, collaboratori, comandi | Principi operativi, rifiuti, tono |
| Se cambia | Cambiano i permessi | Cambia il carattere |

I confini devono essere **prevedibili**: due tester nello stesso progetto hanno gli stessi permessi, e se `IDENTITY.md` fosse scritto a mano ogni copia divergerebbe. Il modo di pensare invece deve essere **specifico**: se fosse generato da un template, tutti gli agenti suonerebbero uguali, e non resterebbe niente che una sessione singola non sappia già fare.

## Sei scritte, trenta da scrivere

`catalog/souls/` contiene sei anime scritte a mano: `ceo`, `engineer`, `product`, `marketing`, `uiux`, `tester`. Per le altre trenta figure il file non esiste, ed è voluto.

Quando avvii per la prima volta un agente il cui ruolo non ha un'anima in catalogo, l'anima viene **scritta in quel momento**, leggendo:

- `<folder>/ROLE-BRIEF.md` — i dati del ruolo: missione, confini, attrito
- `agents/_authoring/SOUL-AUTHORING.md` — le regole di scrittura
- `shared-context/THESIS.md` — cosa crede questo progetto
- `shared-context/BRAND-GUIDE.md` — come suona

**Perché a runtime e non nel catalogo.** Un security engineer su una piattaforma di pagamenti e uno su un blog aziendale non hanno le stesse ossessioni. Un'anima scritta nel catalogo dovrebbe valere per entrambi, e finirebbe per essere generica. Scritta al primo avvio, nasce già dentro il progetto reale: cita i suoi file, i suoi rischi, il suo stack.

Il costo è zero al momento del setup: nessuna chiamata al modello, nessuna attesa, nessun token speso per trenta anime di cui ne userai tre.

## La struttura di un'anima

- **Chi sei** — due o tre frasi. Il mestiere e l'atteggiamento, non il curriculum.
- **Comportamento all'avvio** — leggi SOUL e IDENTITY, poi fermati. Un solo messaggio di ready, nessuna analisi finché non arriva un ordine esplicito.
- **Come pensi** — 4-6 principi operativi. Ognuno dice cosa fai in una situazione concreta.
- **Cosa rifiuti** — 3-5 righe. **Obbligatoria.**
- **Come comunichi** — come suoni quando dai una brutta notizia.
- **Con chi litighi** — il campo `tension` del brief, espanso.

### La sezione dei rifiuti non è opzionale

Un agente senza rifiuti dice sempre di sì. Un tester che approva tutto non è un cancello, è un timbro; un product manager che accetta ogni richiesta non protegge nessuna roadmap. La frizione è la ragione per cui vale la pena avere sei agenti invece di una sessione sola.

Un rifiuto scritto bene porta anche l'alternativa:

> Rifiuti i bug report senza passi di riproduzione. Non li chiudi: li rimandi indietro chiedendo cosa hai fatto, cosa ti aspettavi, cosa è successo.

### Concreto batte astratto

| Non funziona | Funziona |
|---|---|
| "Credi nella qualità" | "Un bug senza passi di riproduzione non è un bug report" |
| "Sei attento alla sicurezza" | "Blocchi il rilascio se trovi un segreto nel codice, anche a un'ora dalla scadenza" |
| "Collabori con il team" | "Quando una spec nasconde un cambio di schema non dichiarato, la rimandi al PM" |

La colonna di sinistra descrive chiunque. Quella di destra dice cosa fare mercoledì alle tre.

## Convenzioni dei file in catalogo

I file in `catalog/souls/` sono template. Tre segnaposto vengono sostituiti alla generazione:

| Segnaposto | Diventa |
|------------|---------|
| `__AGENT_NAME__` | Il nome della persona |
| `__AGENT_ID__` | Il suo id, usato nei comandi |
| `__ROLE_LABEL__` | L'etichetta del ruolo |

Gli **altri** agenti non si citano mai per nome, perché i nomi cambiano da progetto a progetto. Si citano per ruolo:

- nei comandi: `./agents/msg.sh __AGENT_ID__ <tester> "..."`
- in prosa: "il Product Manager", "il Tester"

Chi legge sostituisce mentalmente con la persona giusta, che trova in `shared-context/TEAM.json`. Un'anima che dice "manda un messaggio a marwen" in un team senza Marwen è un'istruzione sbagliata data a un agente.

## Scrivere un'anima a mano

Se vuoi che una figura abbia sempre la stessa anima in ogni progetto, scrivila in `catalog/souls/<slug>.md`. Da quel momento chi assume quel ruolo la riceve già pronta, invece di generarla.

Regole pratiche:

- 40-80 righe. Più corta è vaga, più lunga non viene letta.
- Seconda persona singolare, presente: "Chiedi sempre i passi di riproduzione".
- Niente permessi: quelli stanno in `IDENTITY.md`. Se stai elencando cosa può toccare, hai sbagliato file.
- Il tono segue `shared-context/BRAND-GUIDE.md`.

`catalog/souls/tester.md` e `catalog/souls/uiux.md` sono i due riferimenti per stile e concretezza.

## Riscrivere un'anima esistente

`SOUL.md` è un file normale nella cartella della persona: aprilo e modificalo. Non viene rigenerato né sovrascritto — il passo di authoring scatta **solo** se il file non esiste.

Se vuoi rifarla da capo, cancellala e riavvia l'agente: verrà riscritta dal brief e dal contesto attuale del progetto, che nel frattempo può essere cambiato parecchio.
