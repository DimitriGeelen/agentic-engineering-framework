#!/usr/bin/env bats
# T-2390: bin/fw prefers CLAUDE_PROJECT_DIR (when valid) over the $PWD walk when
# resolving PROJECT_ROOT. Origin: T-2389 live-fire — a spawned session's hooks ran
# with cwd=$HOME (/root), so find_project_root() mis-resolved PROJECT_ROOT (latched
# a stray /root/.tasks or failed), blinding the budget gauge + firing spurious
# project-boundary blocks. Claude Code exports CLAUDE_PROJECT_DIR to hooks as the
# session's project root, independent of the hook's invocation cwd.
#
# Surface under test: bin/fw "Resolve PROJECT_ROOT" block (CLAUDE_PROJECT_DIR
# preference, validity-gated). Observed via `fw version` ("Project: <root>").
#
# AC mapping:
#   valid CLAUDE_PROJECT_DIR wins over $PWD walk      — t1
#   unset CLAUDE_PROJECT_DIR → $PWD walk (bug repro)  — t2  (negative control)
#   invalid CLAUDE_PROJECT_DIR falls through to walk  — t3

load ../test_helper

FW="$BATS_TEST_DIRNAME/../../bin/fw"

setup() {
    # Decoy dir resembles a project ($PWD walk would latch it — the /root/.tasks
    # analogue). Real project carries .framework.yaml (the legitimate root).
    DECOY="$(mktemp -d -t fw-t2390-decoy-XXXXXX)"
    REAL="$(mktemp -d -t fw-t2390-real-XXXXXX)"
    mkdir -p "$DECOY/.tasks"
    mkdir -p "$REAL/.tasks"
    printf 'version: test\n' > "$REAL/.framework.yaml"
}

teardown() {
    rm -rf "$DECOY" "$REAL"
}

@test "t1: valid CLAUDE_PROJECT_DIR is preferred over the \$PWD walk" {
    cd "$DECOY"
    run env -u PROJECT_ROOT CLAUDE_PROJECT_DIR="$REAL" bash "$FW" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Project:.*$REAL"
    ! echo "$output" | grep -q "Project:.*$DECOY"
}

@test "t2: without CLAUDE_PROJECT_DIR, \$PWD walk resolves the decoy (bug repro)" {
    cd "$DECOY"
    run env -u PROJECT_ROOT -u CLAUDE_PROJECT_DIR bash "$FW" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Project:.*$DECOY"
}

@test "t3: invalid CLAUDE_PROJECT_DIR (no .framework.yaml/.tasks) falls through to the walk" {
    local empty
    empty="$(mktemp -d -t fw-t2390-empty-XXXXXX)"
    cd "$DECOY"
    run env -u PROJECT_ROOT CLAUDE_PROJECT_DIR="$empty" bash "$FW" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Project:.*$DECOY"
    ! echo "$output" | grep -q "Project:.*$empty"
    rm -rf "$empty"
}
