#!/usr/bin/env bats
# T-2577 (T-2571 S4) — the designer-ghost leg of the T-2543 FW_TASK_ORIGIN gate.
#
# The save-time ghost mint delegates to the REAL `fw task create`; the GATE — not
# the minting caller — enforces owner:human + captured. These tests pin that leg
# end-to-end against a hermetic temp PROJECT_ROOT (same harness pattern as
# bpmn_promote_e2e.bats): a caller bug (owner:agent, --start) is refused with no
# file written; the conformant shape materializes captured + human-owned.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    [ -f "$FRAMEWORK_ROOT/bin/fw" ] || skip "bin/fw not found"
    cd "$FRAMEWORK_ROOT"

    ROOT="$BATS_TEST_TMPDIR/ghost-gate"
    mkdir -p "$ROOT/.tasks/active" "$ROOT/.tasks/completed" "$ROOT/.context/working"
    cp -r .tasks/templates "$ROOT/.tasks/templates"
}

_create() {
    run env FW_TASK_ORIGIN=designer-ghost PROJECT_ROOT="$ROOT" TASKS_DIR="$ROOT/.tasks" \
        bin/fw task create --name "Document workflow 'x' (referenced, not yet created)" \
        --description "ghost doc task" --type build "$@"
}

@test "gate refuses designer-ghost create with owner:agent (no file written)" {
    _create --owner agent
    [ "$status" -ne 0 ]
    [[ "$output" == *"BLOCKED"* ]]
    [[ "$output" == *"designer-ghost"* ]]
    [[ "$output" == *"owner:human"* ]]
    ! ls "$ROOT/.tasks/active/"T-*.md >/dev/null 2>&1
}

@test "gate refuses designer-ghost create with --start (no file written)" {
    _create --owner human --start
    [ "$status" -ne 0 ]
    [[ "$output" == *"BLOCKED"* ]]
    [[ "$output" == *"captured"* ]]
    ! ls "$ROOT/.tasks/active/"T-*.md >/dev/null 2>&1
}

@test "conformant designer-ghost create lands owner:human + captured + horizon later" {
    _create --owner human --horizon later
    [ "$status" -eq 0 ]
    echo "$output" | grep -Eq "^ID:[[:space:]]+T-"
    f=$(ls "$ROOT/.tasks/active/"T-*.md)
    grep -q "^owner: human" "$f"
    grep -q "^status: captured" "$f"
    grep -q "^horizon: later" "$f"
}
