#!/usr/bin/env bats
# T-5117: the close (and the partial-complete re-run, which calls the same function)
# prints a verdict that exists but does not count. Exercises update-task.sh's own
# apply_reviewer_verdicts against a stub verdict_ledger.py, so only the shell side
# is under test here (the Python side: t5117_not_applied_test.py).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    mkdir -p "$TEST_TEMP_DIR/fw/lib"
    FN="$TEST_TEMP_DIR/fn.sh"
    sed -n '/^apply_reviewer_verdicts() {/,/^}/p' "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" > "$FN"
    [ -s "$FN" ]
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

_stub() {  # $1: stderr line the stub ledger prints, $2: exit code
    cat > "$TEST_TEMP_DIR/fw/lib/verdict_ledger.py" <<EOF
import sys
print('{"ticked": [], "withdrawn": [], "refused": [], "not_applied": []}')
if "$1":
    print("$1", file=sys.stderr)
sys.exit($2)
EOF
}

_run() {
    run bash -c 'YELLOW= GREEN= RED= NC=; NEW_STATUS=work-completed; FRAMEWORK_ROOT="$1"; PROJECT_ROOT="$1"; TASK_ID=T-1100; source "$2"; apply_reviewer_verdicts; echo "rc=$?"' _ "$TEST_TEMP_DIR/fw" "$FN"
}

@test "a NOT APPLIED line from the ledger is printed by the close" {
    _stub "NOT APPLIED: T-1100 AC1 — unknown: the latest verdict V-1 is invalid — stale-review: x" 0
    _run
    [ "$status" -eq 0 ]
    [[ "$output" == *"NOT APPLIED: T-1100 AC1"* ]]
    [[ "$output" == *"stale-review"* ]]
    [[ "$output" == *"rc=0"* ]]
}

@test "control: nothing not-applied prints nothing extra" {
    _stub "" 0
    _run
    [ "$status" -eq 0 ]
    [[ "$output" != *"NOT APPLIED"* ]]
    [[ "$output" == *"rc=0"* ]]
}
