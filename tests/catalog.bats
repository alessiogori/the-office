#!/usr/bin/env bats

load 'helpers/setup'

@test "il catalogo è JSON valido" {
  run python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$OFFICE_ROOT/catalog/roles.json"
  assert_success
}

@test "il catalogo contiene almeno 34 ruoli" {
  run python3 -c "import json,sys; print(len(json.load(open(sys.argv[1]))['roles']))" "$OFFICE_ROOT/catalog/roles.json"
  assert_success
  [ "$output" -ge 34 ]
}

@test "ogni ruolo ha tutti i campi obbligatori non vuoti" {
  run python3 - "$OFFICE_ROOT/catalog/roles.json" <<'PY'
import json, sys
required = ["slug", "label", "category", "mission", "can", "cannot", "collaborates", "tension"]
roles = json.load(open(sys.argv[1]))["roles"]
errors = []
for r in roles:
    for f in required:
        if not r.get(f):
            errors.append(f"{r.get('slug','?')}: campo '{f}' mancante o vuoto")
    if "coordinator" not in r:
        errors.append(f"{r.get('slug','?')}: campo 'coordinator' mancante")
    if "log" not in r or "logTemplate" not in r:
        errors.append(f"{r.get('slug','?')}: campo 'log'/'logTemplate' mancante")
if errors:
    print("\n".join(errors))
    sys.exit(1)
PY
  assert_success
}

@test "gli slug sono univoci" {
  run python3 - "$OFFICE_ROOT/catalog/roles.json" <<'PY'
import json, sys
slugs = [r["slug"] for r in json.load(open(sys.argv[1]))["roles"]]
dupes = set(s for s in slugs if slugs.count(s) > 1)
if dupes:
    print("slug duplicati: " + ", ".join(sorted(dupes)))
    sys.exit(1)
PY
  assert_success
}

@test "esistono almeno cinque ruoli di coordinamento" {
  run python3 -c "import json,sys; print(sum(1 for r in json.load(open(sys.argv[1]))['roles'] if r['coordinator']))" "$OFFICE_ROOT/catalog/roles.json"
  assert_success
  [ "$output" -ge 5 ]
}

@test "collaborates contiene solo slug esistenti" {
  run python3 - "$OFFICE_ROOT/catalog/roles.json" <<'PY'
import json, sys
roles = json.load(open(sys.argv[1]))["roles"]
slugs = {r["slug"] for r in roles}
errors = []
for r in roles:
    for c in r["collaborates"]:
        if c not in slugs:
            errors.append(f"{r['slug']}: collabora con '{c}' che non esiste")
if errors:
    print("\n".join(errors))
    sys.exit(1)
PY
  assert_success
}

@test "i sei ruoli storici sono presenti" {
  for slug in ceo engineer product marketing uiux tester; do
    run python3 - "$OFFICE_ROOT/catalog/roles.json" "$slug" <<'PY'
import json, sys
slugs = {r["slug"] for r in json.load(open(sys.argv[1]))["roles"]}
sys.exit(0 if sys.argv[2] in slugs else 1)
PY
    assert_success
  done
}
