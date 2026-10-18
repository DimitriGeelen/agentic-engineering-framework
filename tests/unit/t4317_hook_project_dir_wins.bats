#!/usr/bin/env bats
# T-4317: inside a Claude Code hook (`fw hook NAME`) a valid CLAUDE_PROJECT_DIR is the
# session's project and must win over the project the cwd happens to sit in. Origin:
# dimitri-mint-dev field case — one `cd` into an unpacked test record that carries its own
# .framework.yaml, and from then on every hook resolved the record: check-project-boundary
# blocked the cd back, budget-gate read the record's CONTEXT_WINDOW, check-active-task read
# the record's focus. The T-2446 cwd-wins rule is for long-lived daemon shells (non-hook fw
# calls) and is kept for them (t3).
#
# Fixtures live under /var/tmp, not /tmp: check-project-boundary allows any cd into /tmp,
# which would make the boundary assertions pass whatever root was resolved.

load ../test_helper

FW="$BATS_TEST_DIRNAME/../../bin/fw"

setup() {
    BASE="$(mktemp -d -p /var/tmp fw-t4317-XXXXXX)"
    A="$BASE/session-project"
    B="$BASE/foreign-record"
    mkdir -p "$A/.tasks/active" "$A/.context/working" "$B/.tasks/active" "$B/.context/working" "$B/sub"
    printf 'version: test\n' > "$A/.framework.yaml"
    printf 'version: test\n' > "$B/.framework.yaml"
    NEUTRAL_HOME="$BASE/home"
    mkdir -p "$NEUTRAL_HOME"
}

teardown() {
    rm -rf "$BASE"
}

_boundary_payload() {
    printf '{"tool_name":"Bash","tool_input":{"command":"cd %s && ls"}}' "$1"
}

@test "t1: hook with CLAUDE_PROJECT_DIR=A and cwd inside foreign project B allows cd back to A" {
    cd "$B/sub"
    run bash -c "printf '%s' '$(_boundary_payload "$A")' | env -u PROJECT_ROOT -u _FW_PATHS_DERIVED_BY -u TASKS_DIR -u CONTEXT_DIR HOME='$NEUTRAL_HOME' CLAUDE_PROJECT_DIR='$A' bash '$FW' hook check-project-boundary"
    [ "$status" -eq 0 ]
    if echo "$output" | grep -q "BLOCKED"; then false; fi
}

@test "t2: hook with CLAUDE_PROJECT_DIR=A and cwd in B resolves A (a cd into B is the outside one)" {
    cd "$B/sub"
    run bash -c "printf '%s' '$(_boundary_payload "$BASE/elsewhere")' | env -u PROJECT_ROOT -u _FW_PATHS_DERIVED_BY -u TASKS_DIR -u CONTEXT_DIR HOME='$NEUTRAL_HOME' CLAUDE_PROJECT_DIR='$A' bash '$FW' hook check-project-boundary"
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "outside project root $A"
    if echo "$output" | grep -q "outside project root $B"; then false; fi
}

@test "t3: non-hook fw call with a stale CLAUDE_PROJECT_DIR and cwd in B still resolves B (T-2446 kept)" {
    cd "$B/sub"
    run env -u PROJECT_ROOT -u _FW_PATHS_DERIVED_BY HOME="$NEUTRAL_HOME" CLAUDE_PROJECT_DIR="$A" bash "$FW" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Project:.*$B"
    if echo "$output" | grep -q "Project:.*$A"; then false; fi
}

@test "t4: hook with a leaked fw root (sentinel) and cwd in B still resolves CLAUDE_PROJECT_DIR=A" {
    cd "$B/sub"
    run bash -c "printf '%s' '$(_boundary_payload "$A")' | env -u TASKS_DIR -u CONTEXT_DIR HOME='$NEUTRAL_HOME' CLAUDE_PROJECT_DIR='$A' PROJECT_ROOT='$B' _FW_PATHS_DERIVED_BY='$B' bash '$FW' hook check-project-boundary"
    [ "$status" -eq 0 ]
    if echo "$output" | grep -q "BLOCKED"; then false; fi
}
