#!/usr/bin/env bats
# T-4154: every AEF module (fabric subsystem) is declared and carries a capability
# card that meets the T-4153 bar. Invariants over the committed registry, not counts.

setup() {
    ROOT="$BATS_TEST_DIRNAME/../.."
}

@test "every subsystem a component card names is declared in subsystems.yaml" {
    run python3 -I - "$ROOT" <<'PY'
import glob, sys, yaml
root = sys.argv[1]
declared = {s["id"] for s in yaml.safe_load(open(f"{root}/.fabric/subsystems.yaml"))["subsystems"]}
used = set()
for p in glob.glob(f"{root}/.fabric/components/*.yaml"):
    try:
        card = yaml.safe_load(open(p)) or {}
    except Exception:
        continue
    if card.get("subsystem"):
        used.add(card["subsystem"])
missing = sorted(used - declared - {"unknown"})
print("undeclared:", missing)
sys.exit(1 if missing else 0)
PY
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "strict capability-card lint passes on the real registry (every subsystem carded)" {
    run python3 -I "$ROOT/agents/fabric/lib/cardlint.py" "$ROOT/.fabric/subsystems.yaml" --strict
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *" 0 problem(s), 0 subsystem(s) without a card"* ]]
}
