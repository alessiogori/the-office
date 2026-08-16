# Estendere il catalogo

Le 36 figure coprono lo sviluppo software e il go-to-market. Non coprono tutto: un'agenzia creativa, uno studio legale o un team di ricerca hanno mestieri che qui non ci sono.

Aggiungere una figura è un'operazione sui dati. Non serve toccare codice.

## Una voce nuova

Aggiungi un oggetto all'array `roles` in `catalog/roles.json`:

```json
{
  "slug": "localization",
  "label": "Localization Manager",
  "category": "Operations",
  "coordinator": false,
  "mission": "Traduzioni e adattamento culturale. Una stringa tradotta male costa più di una non tradotta.",
  "can": [
    "Leggere e scrivere file di traduzione e glossari terminologici",
    "Rifiutare una stringa non traducibile perché concatenata nel codice"
  ],
  "cannot": [
    "Modificare il codice applicativo: segnala e verifica",
    "Cambiare il microcopy originale: è dell'UX Writer"
  ],
  "collaborates": ["ux-writer", "frontend", "product"],
  "log": "L10N-LOG.md",
  "logTemplate": "generic",
  "tension": "Blocca le stringhe concatenate a runtime, che in tedesco e in giapponese si rompono"
}
```

Poi:

```bash
./tests/run.sh tests/catalog.bats
python3 docs/genera-catalogo.py > docs/catalogo-ruoli.md
```

Da quel momento `setup.sh` e `hire.sh` vedono la figura. Nessun codice modificato.

## I campi

| Campo | Obbligatorio | Note |
|-------|--------------|------|
| `slug` | sì | Univoco, minuscolo, trattini. È la chiave |
| `label` | sì | Come appare all'utente |
| `category` | sì | Raggruppa nel filtro del wizard. Riusa una esistente se ha senso |
| `coordinator` | sì | `true` solo per chi organizza il lavoro altrui |
| `mission` | sì | Una o due frasi: cosa possiede |
| `can` | sì | 2-4 voci |
| `cannot` | sì | 1-3 voci. Almeno una verso un altro ruolo |
| `collaborates` | sì | Solo slug esistenti, altrimenti il test fallisce |
| `log` | sì (può essere `null`) | Nome del file di log |
| `logTemplate` | sì (può essere `null`) | Uno dei template disponibili |
| `tension` | sì | Contro chi spinge e su cosa |

I template di log disponibili sono in `catalog/templates/`: `build-log`, `backlog`, `calendar`, `review-log`, `bug-log`, `generic`. Se nessuno calza, usa `generic` — oppure aggiungine uno nuovo, ricordando i segnaposto `__AGENT_NAME__` e `__ROLE_LABEL__`.

## Scrivere bene i campi che contano

### `cannot` — i confini veri

Il senso del campo è che due agenti non si calpestino. Un `cannot` generico non serve a nessuno.

| Debole | Forte |
|--------|-------|
| "Non fare danni" | "Non modificare il backend: è del Backend Engineer" |
| "Non uscire dal suo ruolo" | "Non chiudere un bug senza verifica del fix" |
| "Non prendere decisioni sbagliate" | "Non cambiare il contratto di un'API senza versionarla" |

Almeno una voce deve nominare un confine verso un altro ruolo del catalogo. Se non riesci a scriverla, forse la figura si sovrappone a una esistente e non serve una voce nuova.

### `tension` — l'attrito

È il campo che rende operativa la regola "i disaccordi sono un bene". Deve dire **contro chi** e **su cosa**.

| Debole | Forte |
|--------|-------|
| "Collabora con tutti" | "Blocca i rilasci del venerdì e i deploy senza rollback" |
| "Tiene alta la qualità" | "Rifiuta i test instabili rilanciati finché passano" |
| "È attento ai costi" | "Porta il costo per utente al tavolo quando si discute solo di crescita" |

Un ruolo senza attrito diventa un sì-uomo, e un sì-uomo non aggiunge niente a una sessione singola.

## Cosa verificano i test

`tests/catalog.bats` controlla:

- il JSON è valido
- ci sono almeno 34 ruoli e almeno 5 coordinatori
- ogni voce ha tutti i campi obbligatori, non vuoti
- gli slug sono univoci
- ogni slug in `collaborates` esiste
- ogni `logTemplate` referenziato esiste come file
- i sei ruoli storici sono ancora presenti

Se aggiungi una voce incompleta il test fallisce dicendoti quale campo manca su quale slug.

## L'anima della figura nuova

Non serve scriverla. Una figura senza `catalog/souls/<slug>.md` riceve l'anima al primo avvio, generata dal suo `ROLE-BRIEF.md` e dal contesto del progetto.

Se vuoi che quella figura abbia sempre lo stesso carattere ovunque, scrivi il file seguendo [Le anime](anime.md).

## Rimuovere o rinominare una figura

Rinominare uno `slug` rompe i progetti già generati: il loro `TEAM.json` contiene il vecchio slug, e `roster_role_get` non lo troverà più. In pratica smette di funzionare `hire.sh` per quel ruolo e la generazione dei documenti.

Se devi farlo, aggiungi la nuova voce e lascia la vecchia. Il costo di una voce in più in un JSON è nullo; il costo di un manifest che punta al vuoto lo paga chi usa il sistema.
