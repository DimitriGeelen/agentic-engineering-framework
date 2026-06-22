#!/usr/bin/env bats
# T-2457 / OBS-080: fabric card writes must be atomic.
#
# Bug: both card writers truncated-then-streamed the destination card:
#   - register.sh:266  `cat > "$card_file" << EOF`
#   - enrich.py:34     `with open(path, "w") as f:`
# A concurrent reader — notably `fw fabric drift` building its registered set
# via `grep "^location:" "$COMPONENTS_DIR"/*.yaml` — could observe a card after
# truncation but before the `location:` line was written. That card's source
# path then dropped out of the registered set, so the file it points to was
# reported "unregistered" — a spurious FP that cleared on immediate re-run once
# the write completed (observed 2x during T-2440, which was actively
# registering cards).
#
# Fix: write to a same-dir temp file, then atomic rename (mv -f / os.replace).
# A reader always sees either the complete old card or the complete new one,
# never a partial. These tests pin (1) the FP-relevant property — a freshly
# written card always carries `location:` and parses — (2) no .tmp residue,
# and (3) the atomic-rename source pattern (so a future edit can't silently
# regress to a bare truncate-write).

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
REGISTER_SH="$FRAMEWORK_ROOT/agents/fabric/lib/register.sh"
ENRICH_PY="$FRAMEWORK_ROOT/agents/fabric/lib/enrich.py"

setup() {
    TMP_PROJECT=$(mktemp -d)
    mkdir -p "$TMP_PROJECT/.fabric/components"
    mkdir -p "$TMP_PROJECT/lib"
    touch "$TMP_PROJECT/lib/pickup.sh"

    export PROJECT_ROOT="$TMP_PROJECT"
    export FABRIC_DIR="$TMP_PROJECT/.fabric"
    export COMPONENTS_DIR="$FABRIC_DIR/components"
    export RED="" GREEN="" YELLOW="" CYAN="" BOLD="" NC=""

    ensure_fabric_dirs() { :; }
    export -f ensure_fabric_dirs 2>/dev/null || true

    # shellcheck source=agents/fabric/lib/register.sh
    source "$REGISTER_SH"
}

teardown() {
    rm -rf "$TMP_PROJECT"
}

# --- register.sh: functional (the FP-relevant property) ---

@test "register: created card carries a location: line and parses (T-2457)" {
    _do_register_file "lib/pickup.sh" >/dev/null
    card="$COMPONENTS_DIR/lib-pickup.yaml"
    [ -f "$card" ]
    # location: present — its momentary absence under a non-atomic write was the FP
    grep -q "^location: lib/pickup.sh$" "$card"
    run python3 -c "import yaml,sys; d=yaml.safe_load(open('$card')); print(d['location'])"
    [ "$status" -eq 0 ]
    [ "$output" = "lib/pickup.sh" ]
}

@test "register: no .tmp residue after card creation (T-2457)" {
    _do_register_file "lib/pickup.sh" >/dev/null
    # The atomic mv consumes the temp file; nothing left behind
    run bash -c "ls '$COMPONENTS_DIR'/*.tmp 2>/dev/null"
    [ "$status" -ne 0 ]
    [ -z "$output" ]
}

# --- register.sh: source pin (atomic rename, no bare truncate-write) ---

@test "register: writes via same-dir temp + atomic mv -f, not bare cat > card (T-2457)" {
    # Positive: the atomic rename onto the real card path is present
    grep -qE 'mv -f "\$tmp_card" "\$card_file"' "$REGISTER_SH"
    # Negative: no bare quoted truncate-write to the real card path remains
    ! grep -qE 'cat >[[:space:]]+"\$card_file"' "$REGISTER_SH"
}

# --- enrich.py: functional ---

@test "enrich save_card: writes a complete card, no .tmp residue (T-2457)" {
    run env FRAMEWORK_ROOT="$FRAMEWORK_ROOT" python3 - "$TMP_PROJECT" <<'PY'
import sys, os, yaml
sys.path.insert(0, os.environ["FRAMEWORK_ROOT"] + "/agents/fabric/lib")
import enrich
d = sys.argv[1]
p = os.path.join(d, ".fabric", "components", "card.yaml")
enrich.save_card(p, {"id": "x", "location": "lib/pickup.sh",
                     "depends_on": [], "depended_by": []})
data = yaml.safe_load(open(p))
assert data["location"] == "lib/pickup.sh", data
assert not os.path.exists(p + ".tmp"), "tmp residue left behind"
print("OK")
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

# --- enrich.py: source pin (os.replace, no bare open(path,"w")) ---

@test "enrich save_card: uses os.replace onto a temp, not bare open(path,\"w\") (T-2457)" {
    # Positive: atomic rename + temp open present
    grep -q 'os.replace(tmp, path)' "$ENRICH_PY"
    grep -q 'open(tmp, "w")' "$ENRICH_PY"
    # Negative: the old non-atomic truncate-open onto the live path is gone.
    # Match the code form `with open(path, "w")` so the docstring's prose
    # reference to the old pattern doesn't count as a regression.
    ! grep -q 'with open(path, "w")' "$ENRICH_PY"
}
