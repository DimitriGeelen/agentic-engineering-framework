#!/usr/bin/env bats
# T-5088 (GitHub #108) — `fw fabric register` wrote the card, exited 0, and printed
# "REFUSED: ... no subsystem rule matches". Output and exit code disagreed. The card is
# written on purpose (T-3430: leave a field unfilled rather than guess), so the output now
# says which fields were NOT FILLED and how to fill them.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TMP_PROJECT=$(mktemp -d)
    mkdir -p "$TMP_PROJECT/.fabric/components" "$TMP_PROJECT/odd"
    printf 'x = 1\n' > "$TMP_PROJECT/odd/thing.py"          # no docstring, no subsystem rule
    export PROJECT_ROOT="$TMP_PROJECT"
    export FABRIC_DIR="$TMP_PROJECT/.fabric"
    export COMPONENTS_DIR="$FABRIC_DIR/components"
    export RED="" GREEN="" YELLOW="" CYAN="" BOLD="" NC=""
    ensure_fabric_dirs() { :; }
    source "$FRAMEWORK_ROOT/agents/fabric/lib/register.sh"
}

teardown() { rm -rf "$TMP_PROJECT"; }

@test "T-5088: an unmatched path writes the card, exits 0, and says what was not filled" {
    run bash -c 'true'   # keep bats happy about run state
    out=$(cd "$TMP_PROJECT" && _do_register_file odd/thing.py 2>&1); rc=$?
    [ "$rc" -eq 0 ]
    [ -f "$COMPONENTS_DIR/odd-thing.yaml" ]
    [[ "$out" == *"Card created"* ]]
    [[ "$out" == *"NOT FILLED: subsystem"* ]]
    [[ "$out" == *"fw fabric enrich"* ]]
}

@test "T-5088: no REFUSED when the card was written" {
    out=$(cd "$TMP_PROJECT" && _do_register_file odd/thing.py 2>&1)
    [[ "$out" != *"REFUSED"* ]]
}

@test "T-5088: a missing purpose is reported as NOT FILLED too" {
    out=$(cd "$TMP_PROJECT" && _do_register_file odd/thing.py 2>&1)
    [[ "$out" == *"NOT FILLED: purpose"* ]]
}
