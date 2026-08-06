#!/usr/bin/env bats
# T-2830 — `fw work-on <name> --type build --switch-focus` exited 1 printing
# ZERO bytes on both streams. Two composing defects, both pinned here:
#
#   1. Parity gap (L-399 / T-1890). --switch-focus is the focus-drift bypass
#      contract. T-1890 shipped the silent no-op branch into update-task.sh and
#      lib/{learning,pattern,decision}.sh but not into create-task.sh, which
#      `fw work-on` shells to on the CREATE path.
#
#   2. Silent swallow. bin/fw runs under `set -euo pipefail`. The create path was
#      `wo_output=$(create-task.sh ... 2>&1)` then `echo "$wo_output"`. When the
#      substitution exits non-zero, set -e terminates fw AT THE ASSIGNMENT, so the
#      captured message is discarded and never printed.
#
# Defect 2 is the one that matters. Defect 1 alone is a ten-second fix once you can
# see "Unknown option: --switch-focus"; defect 2 is what made it invisible. Test 3
# is therefore the load-bearing test — it pins that a downstream failure REACHES
# the terminal, independent of which flag happens to be rejected.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export TASKS_DIR="$TEST_TEMP_DIR/.tasks"
    export CONTEXT_DIR="$TEST_TEMP_DIR/.context"
    export NO_COLOR=1
    unset CLAUDECODE
    unset AI_AGENT

    mkdir -p "$TASKS_DIR/active" "$TASKS_DIR/completed" "$TASKS_DIR/templates"
    mkdir -p "$CONTEXT_DIR/working"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    cp "$FRAMEWORK_ROOT/.tasks/templates/zzz-default.md" "$TASKS_DIR/templates/" 2>/dev/null || true
}

teardown() {
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ──────────────────────────────────────────────────────────────────────────────
# Defect 1 — the parity gap
# ──────────────────────────────────────────────────────────────────────────────

@test "create-task.sh consumes --switch-focus silently (T-1890 contract parity)" {
    run "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" \
        --name "parity probe" --type build --description d --owner agent --switch-focus
    [ "$status" -eq 0 ]
    [[ "$output" != *"Unknown option"* ]]
    [[ "$output" == *"Task Created"* ]]
}

@test "fw work-on accepts --switch-focus end-to-end" {
    run "$FRAMEWORK_ROOT/bin/fw" work-on "e2e probe" --type build --switch-focus
    [ "$status" -eq 0 ]
    [[ "$output" != *"Unknown option"* ]]
    [[ "$output" == *"Ready to work on"* ]]
}

# ──────────────────────────────────────────────────────────────────────────────
# Defect 2 — the silent swallow. THE load-bearing test.
# ──────────────────────────────────────────────────────────────────────────────

@test "a failing create under fw work-on REACHES the terminal (no silent swallow)" {
    # Precondition: assert the downstream really does fail and really does say
    # something. Without this, a green below could mean "fw surfaced the error" OR
    # "nothing failed at all" — the T-2828 vacuous-control shape.
    run "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" \
        --name "neg" --type build --description d --owner agent --definitely-not-a-flag
    [ "$status" -ne 0 ]
    [ -n "$output" ]

    # The actual regression: fw must not eat that message.
    run "$FRAMEWORK_ROOT/bin/fw" work-on "neg probe" --type build --definitely-not-a-flag
    [ "$status" -ne 0 ]
    [ -n "$output" ]                            # <-- was EMPTY before the fix
    [[ "$output" == *"Unknown option"* ]]       # the downstream message itself
    [[ "$output" == *"no task created"* ]]      # fw's own framing of the failure
}

@test "a failing create under fw work-on does not leave a half-made task" {
    run "$FRAMEWORK_ROOT/bin/fw" work-on "neg probe 2" --type build --definitely-not-a-flag
    [ "$status" -ne 0 ]
    run bash -c "ls '$TASKS_DIR/active' 2>/dev/null | wc -l"
    [ "$output" = "0" ]
}
