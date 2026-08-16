# Documentazione — the-office

Un sistema multi-agente in cui componi il team che ti serve, da un catalogo di 36 figure, e ogni agente ha confini di accesso reali e un attrito dichiarato verso i colleghi.

## Da dove iniziare

| Documento | Quando leggerlo |
|-----------|-----------------|
| [Guida introduttiva](getting-started.md) | Prima installazione: dal clone al primo agente avviato |
| [Catalogo dei ruoli](catalogo-ruoli.md) | Devi scegliere chi mettere nel team |
| [Comandi](comandi.md) | Reference di tutti gli script, opzione per opzione |
| [Architettura](architettura.md) | Devi modificare il sistema, non solo usarlo |
| [Le anime](anime.md) | Vuoi capire o scrivere un `SOUL.md` |
| [Estendere il catalogo](estendere-il-catalogo.md) | Ti serve una figura che non c'è |
| [Testing](testing.md) | Stai contribuendo al codice |

## In due minuti

```bash
git clone --recurse-submodules https://github.com/alessiogori/the-office.git
cd the-office
./setup.sh
```

Il wizard chiede quante persone servono, chi coordina, e che ruolo ha ciascun altro. Genera un progetto dove ogni persona ha una cartella, un'identità e dei confini, e dove gli script sanno chi c'è.

Poi:

```bash
cd <tuo-progetto>
./agents/dashboard.sh     # chi c'è, chi lavora, su cosa
./agents/iterm.sh all     # una finestra per ciascuno
```

## I tre concetti che spiegano tutto il resto

**Il catalogo è il possibile, il manifest è l'attuale.** `catalog/roles.json` descrive 36 figure con le loro competenze e i loro limiti. `shared-context/TEAM.json` dice chi c'è davvero in *questo* progetto. Nessuno script contiene un elenco di agenti: leggono tutti il manifest.

**L'identità è generata, l'anima è scritta.** `IDENTITY.md` — cosa un agente può e non può toccare — è derivato meccanicamente dai dati del ruolo, perché i confini devono essere prevedibili. `SOUL.md` — come pensa, cosa rifiuta — è scritto, e per le figure che non ne hanno una in catalogo viene scritto al primo avvio, calato sul progetto reale.

**Il conflitto è progettato.** Ogni ruolo ha un campo `tension`: contro chi spinge e su cosa. Un tester che approva tutto e un product manager che accetta ogni richiesta non aggiungono niente a una sessione singola. La frizione è la ragione per cui vale la pena avere più agenti.
