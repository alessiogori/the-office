#!/usr/bin/env python3
"""Genera docs/catalogo-ruoli.md da catalog/roles.json.

Il catalogo è la sorgente di verità: questa reference non va scritta a mano,
altrimenti diverge al primo ruolo aggiunto.

    python3 docs/genera-catalogo.py > docs/catalogo-ruoli.md
"""
import json
import os
import sys
from collections import OrderedDict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, "catalog", "roles.json")


def anchor(text):
    """Ancora GitHub-style per un titolo di sezione."""
    out = text.lower()
    for a, b in [("à", "a"), ("è", "e"), ("é", "e"), ("ì", "i"), ("ò", "o"), ("ù", "u")]:
        out = out.replace(a, b)
    return "".join(c if c.isalnum() else "-" for c in out).strip("-")


def main():
    roles = json.load(open(CATALOG))["roles"]
    labels = {r["slug"]: r["label"] for r in roles}

    cats = OrderedDict()
    for r in roles:
        cats.setdefault(r["category"], []).append(r)

    n_coord = sum(1 for r in roles if r["coordinator"])
    p = print

    p("# Catalogo dei ruoli")
    p()
    p("Le figure che puoi mettere in un team. **La sorgente di verità è "
      "`catalog/roles.json`**: questo documento ne è una resa leggibile, rigenerata "
      "dallo script `docs/genera-catalogo.py`. Non modificarlo a mano.")
    p()
    p(f"Al momento: **{len(roles)} figure** in {len(cats)} categorie, "
      f"di cui {n_coord} di coordinamento.")
    p()

    p("## Come si legge una voce")
    p()
    p("Ogni figura porta cinque informazioni, che finiscono nei file dell'agente:")
    p()
    p("| Campo | Dove finisce | A cosa serve |")
    p("|-------|--------------|--------------|")
    p("| `mission` | `IDENTITY.md`, `ROLE-BRIEF.md` | Cosa possiede, in una frase |")
    p("| `can` | `IDENTITY.md` | Cosa gli è permesso fare |")
    p("| `cannot` | `IDENTITY.md` | I confini verso gli altri ruoli. Vincolanti |")
    p("| `collaborates` | `IDENTITY.md` | Con chi si coordina abitualmente |")
    p("| `tension` | `IDENTITY.md`, `ROLE-BRIEF.md` | Contro chi spinge e su cosa |")
    p()
    p("`tension` è il campo che distingue questo catalogo da un elenco di mansioni. "
      "Un agente senza attrito dichiarato approva tutto, e un approvatore automatico "
      "non aggiunge niente rispetto a una sessione singola.")
    p()

    p("## Indice")
    p()
    for cat, rs in cats.items():
        p(f"- [{cat}](#{anchor(cat)}) — {len(rs)} figure")
    p()

    for cat, rs in cats.items():
        p(f"## {cat}")
        p()
        if rs[0]["coordinator"]:
            p("Un team deve avere **almeno una** di queste figure, ed è sempre la prima "
              "persona che il wizard chiede.")
            p()
        for r in rs:
            p(f"### {r['label']}")
            p()
            meta = [f"`{r['slug']}`"]
            if r["coordinator"]:
                meta.append("**coordinamento**")
            meta.append(f"log: `{r['log']}`" if r["log"] else "nessun log dedicato")
            p(" · ".join(meta))
            p()
            p(r["mission"])
            p()
            p("**Può:**")
            p()
            for c in r["can"]:
                p(f"- {c}")
            p()
            p("**Non può:**")
            p()
            for c in r["cannot"]:
                p(f"- {c}")
            p()
            p("**Lavora con:** " + ", ".join(labels[c] for c in r["collaborates"]))
            p()
            p(f"**Attrito:** {r['tension']}")
            p()

    p("---")
    p()
    p("## Rigenerare questo documento")
    p()
    p("```bash")
    p("python3 docs/genera-catalogo.py > docs/catalogo-ruoli.md")
    p("```")
    p()
    p("Per aggiungere una figura vedi [Estendere il catalogo](estendere-il-catalogo.md).")


if __name__ == "__main__":
    sys.exit(main())
