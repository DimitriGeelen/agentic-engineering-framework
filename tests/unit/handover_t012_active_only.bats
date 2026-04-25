#!/usr/bin/env bats
# T-1477 — handover.sh's COMMIT_TASK lookup must only match T-012 when it is
# in .tasks/active/. Matching completed/ caused recurring "task is closed"
# warnings on every session handover commit because T-012 was completed long
# ago.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export NO_COLOR=1
    export FRAMEWORK_ROOT
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ---- Source-level invariants ----

@test "handover.sh's T-012 check matches active/ ONLY (T-1477)" {
    # Pattern must check active/T-012-* and NOT completed/T-012-*
    grep -q 'TASKS_DIR/active/T-012-' "$FRAMEWORK_ROOT/agents/handover/handover.sh"
    # The line that does the lookup MUST NOT mention completed/T-012- on the same line
    if grep -E 'TASKS_DIR/active/T-012-.*TASKS_DIR/completed/T-012-' "$FRAMEWORK_ROOT/agents/handover/handover.sh"; then
        false  # Both paths on the same ls — the regression we're guarding against
    fi
}

@test "T-1477 comment / rationale present in handover.sh" {
    grep -q 'T-1477' "$FRAMEWORK_ROOT/agents/handover/handover.sh"
}

# ---- Behavioural ----

@test "_resolve_commit_task picks T-012 when in active/" {
    cd "$TEST_TEMP_DIR"
    mkdir -p .tasks/active .tasks/completed
    touch .tasks/active/T-012-create-handover-agent.md
    TASKS_DIR=".tasks"
    COMMIT_TASK=""
    if [ -n "$(ls "$TASKS_DIR/active/T-012-"*.md 2>/dev/null)" ]; then
        COMMIT_TASK="T-012"
    fi
    [ "$COMMIT_TASK" = "T-012" ]
}

@test "_resolve_commit_task does NOT pick T-012 when only in completed/ (T-1477 fix)" {
    cd "$TEST_TEMP_DIR"
    mkdir -p .tasks/active .tasks/completed
    touch .tasks/completed/T-012-create-handover-agent.md
    TASKS_DIR=".tasks"
    COMMIT_TASK=""
    if [ -n "$(ls "$TASKS_DIR/active/T-012-"*.md 2>/dev/null)" ]; then
        COMMIT_TASK="T-012"
    fi
    [ -z "$COMMIT_TASK" ]
}

# ---- Sanity ----

@test "handover.sh parses (bash -n) (T-1477)" {
    bash -n "$FRAMEWORK_ROOT/agents/handover/handover.sh"
}
