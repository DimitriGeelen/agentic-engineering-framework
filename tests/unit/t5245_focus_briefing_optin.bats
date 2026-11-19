#!/usr/bin/env bats
# T-5245: fw context focus runs the lib/ask.py task briefing only when
# FOCUS_BRIEFING is 1. Measured 2026-11-19 the briefing timed out every time
# (15 s, exit 124, no output), so every focus waited ~15 s for nothing.
#
# A stub FRAMEWORK_ROOT holds a fake lib/ask.py that leaves a marker file, so
# each test proves whether the briefing was invoked, not just what was printed.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR/project"
    guard_project_root
    export CONTEXT_DIR="$PROJECT_ROOT/.context"
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.context/working"
    RED='' GREEN='' YELLOW='' CYAN='' NC=''
    ensure_context_dirs() { mkdir -p "$CONTEXT_DIR/working"; }
    export -f ensure_context_dirs
    export TASKS_DIR="$PROJECT_ROOT/.tasks"

    REAL_ROOT="$FRAMEWORK_ROOT"
    source "$REAL_ROOT/lib/compat.sh"
    source "$REAL_ROOT/lib/tasks.sh"
    source "$REAL_ROOT/agents/context/lib/focus.sh"

    # Stub framework root: real config.sh, fake ask.py, no recall script.
    STUB_ROOT="$TEST_TEMP_DIR/fw"
    mkdir -p "$STUB_ROOT/lib"
    ln -s "$REAL_ROOT/lib/config.sh" "$STUB_ROOT/lib/config.sh"
    MARKER="$TEST_TEMP_DIR/ask-called"
    cat > "$STUB_ROOT/lib/ask.py" <<EOF
open("$MARKER", "w").write("called")
print("stub briefing")
EOF
    export FRAMEWORK_ROOT="$STUB_ROOT"
    unset FW_FOCUS_BRIEFING
}

teardown() {
    export FRAMEWORK_ROOT="$REAL_ROOT"
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "default: focus does not run the briefing" {
    create_test_task "$PROJECT_ROOT" "T-042" "fix-login"
    run do_focus T-042
    [ "$status" -eq 0 ]
    [[ "$output" == *"Focus set: T-042"* ]]
    [ ! -f "$MARKER" ]
    [[ "$output" != *"Task Briefing"* ]]
}

@test "FW_FOCUS_BRIEFING=1: focus runs the briefing" {
    create_test_task "$PROJECT_ROOT" "T-042" "fix-login"
    export FW_FOCUS_BRIEFING=1
    run do_focus T-042
    [ "$status" -eq 0 ]
    [ -f "$MARKER" ]
    [[ "$output" == *"stub briefing"* ]]
}

@test "config FOCUS_BRIEFING: 1 in .framework.yaml runs the briefing" {
    create_test_task "$PROJECT_ROOT" "T-042" "fix-login"
    printf 'FOCUS_BRIEFING: 1\n' > "$PROJECT_ROOT/.framework.yaml"
    run do_focus T-042
    [ "$status" -eq 0 ]
    [ -f "$MARKER" ]
}

@test "control: FW_FOCUS_BRIEFING=0 overrides a config of 1" {
    create_test_task "$PROJECT_ROOT" "T-042" "fix-login"
    printf 'FOCUS_BRIEFING: 1\n' > "$PROJECT_ROOT/.framework.yaml"
    export FW_FOCUS_BRIEFING=0
    run do_focus T-042
    [ "$status" -eq 0 ]
    [ ! -f "$MARKER" ]
}
