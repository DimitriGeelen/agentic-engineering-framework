#!/usr/bin/env bats
# T-1716: filing-time --recommendation/--rationale gate on fw inception start
#
# Tests:
#   A1: under $CLAUDECODE=1 with neither flag → exit 1 with required-flag message
#   A2: --recommendation GO + --rationale "..." → succeeds; task file has real
#       Recommendation block (not template-comment placeholder)
#   A3: --recommendation/--rationale validation: invalid value rejected
#   A4: --i-am-human override allows filing without flags + writes bypass-log entry
#   A5: gate is gated on $CLAUDECODE=1; absent (human shell) → no flags required
#   A6: --recommendation alone without --rationale still fails under $CLAUDECODE=1

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export AGENTS_DIR="$FRAMEWORK_ROOT/agents"
    export FW_LIB_DIR="$FRAMEWORK_ROOT/lib"
    export NO_COLOR=1
    unset CLAUDECODE
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/errors.sh"
    source "$FRAMEWORK_ROOT/lib/tasks.sh"
    source "$FRAMEWORK_ROOT/lib/inception.sh"

    mkdir -p "$TEST_TEMP_DIR/.tasks/active"
    mkdir -p "$TEST_TEMP_DIR/.tasks/completed"
    mkdir -p "$TEST_TEMP_DIR/.tasks/templates"
    mkdir -p "$TEST_TEMP_DIR/.context/working"

    # Copy the inception template so create-task.sh has a template to expand
    cp "$FRAMEWORK_ROOT/.tasks/templates/inception.md" \
       "$TEST_TEMP_DIR/.tasks/templates/inception.md"
    cp "$FRAMEWORK_ROOT/.tasks/templates/default.md" \
       "$TEST_TEMP_DIR/.tasks/templates/default.md" 2>/dev/null || true
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ---------- A1: gate fires when no flags under $CLAUDECODE=1 ----------

@test "inception start: under \$CLAUDECODE=1 + no flags → exit 1" {
    CLAUDECODE=1 run do_inception_start "test inception name"
    [ "$status" -eq 1 ]
    [[ "$output" == *"--recommendation and --rationale required"* ]]
    [[ "$output" == *"T-1715"* ]]
}

@test "inception start: error message includes example invocation" {
    CLAUDECODE=1 run do_inception_start "test inception name"
    [ "$status" -eq 1 ]
    [[ "$output" == *"--recommendation GO|NO-GO|DEFER"* ]]
    [[ "$output" == *"--rationale"* ]]
}

# ---------- A2: real Recommendation injected when both flags provided ----------

@test "inception start: --recommendation GO + --rationale → injects real block" {
    CLAUDECODE=1 run do_inception_start "test inception" \
        --recommendation GO \
        --rationale "Smoke test rationale citing evidence X and Y"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Injected Recommendation: GO"* ]]

    # Find the created task file
    local task_file
    task_file=$(find "$TEST_TEMP_DIR/.tasks/active" -name "T-*.md" -type f | head -1)
    [ -n "$task_file" ]
    [ -f "$task_file" ]

    # Real Recommendation block present
    grep -q "^\*\*Recommendation:\*\* GO" "$task_file"
    grep -q "Smoke test rationale citing evidence X and Y" "$task_file"

    # Template-comment placeholder gone
    ! grep -q "REQUIRED before fw inception decide" "$task_file"
}

@test "inception start: DEFER recommendation also accepted" {
    CLAUDECODE=1 run do_inception_start "deferred idea" \
        --recommendation DEFER \
        --rationale "Captured for later, no exploration done"
    [ "$status" -eq 0 ]

    local task_file
    task_file=$(find "$TEST_TEMP_DIR/.tasks/active" -name "T-*.md" -type f | head -1)
    grep -q "^\*\*Recommendation:\*\* DEFER" "$task_file"
}

@test "inception start: NO-GO recommendation also accepted" {
    CLAUDECODE=1 run do_inception_start "rejected idea" \
        --recommendation NO-GO \
        --rationale "Cost exceeds value given current evidence"
    [ "$status" -eq 0 ]

    local task_file
    task_file=$(find "$TEST_TEMP_DIR/.tasks/active" -name "T-*.md" -type f | head -1)
    grep -q "^\*\*Recommendation:\*\* NO-GO" "$task_file"
}

# ---------- A3: invalid recommendation value rejected ----------

@test "inception start: invalid --recommendation value rejected" {
    CLAUDECODE=1 run do_inception_start "test" \
        --recommendation MAYBE \
        --rationale "trying invalid"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid --recommendation"* ]]
    [[ "$output" == *"MAYBE"* ]]
}

@test "inception start: lowercase 'go' rejected (case-sensitive)" {
    CLAUDECODE=1 run do_inception_start "test" \
        --recommendation go \
        --rationale "lowercase test"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid --recommendation"* ]]
}

# ---------- A4: --i-am-human override ----------

@test "inception start: --i-am-human bypasses gate under \$CLAUDECODE=1" {
    CLAUDECODE=1 run do_inception_start "scripted filing" --i-am-human
    [ "$status" -eq 0 ]
    [[ "$output" != *"--recommendation and --rationale required"* ]]
}

@test "inception start: --i-am-human writes bypass-log entry" {
    CLAUDECODE=1 run do_inception_start "scripted filing" --i-am-human
    [ "$status" -eq 0 ]
    local log="$TEST_TEMP_DIR/.context/working/.gate-bypass-log.yaml"
    [ -f "$log" ]
    grep -q "flag: '--i-am-human'" "$log"
    grep -q "caller: 'do_inception_start'" "$log"
    grep -q "T-1715/T-1716" "$log"
}

# ---------- A5: gate gated on $CLAUDECODE=1 ----------

@test "inception start: without \$CLAUDECODE=1 → no flags required" {
    unset CLAUDECODE
    run do_inception_start "human-shell filing"
    [ "$status" -eq 0 ]
    [[ "$output" != *"--recommendation and --rationale required"* ]]
}

@test "inception start: without \$CLAUDECODE=1 + with flags → still injects" {
    unset CLAUDECODE
    run do_inception_start "human shell with flags" \
        --recommendation GO \
        --rationale "human used flags voluntarily"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Injected Recommendation: GO"* ]]
}

# ---------- A6: half-pair fails ----------

@test "inception start: --recommendation alone (no --rationale) fails" {
    CLAUDECODE=1 run do_inception_start "test" --recommendation GO
    [ "$status" -eq 1 ]
    [[ "$output" == *"--recommendation and --rationale required"* ]]
}

@test "inception start: --rationale alone (no --recommendation) fails" {
    CLAUDECODE=1 run do_inception_start "test" --rationale "without rec"
    [ "$status" -eq 1 ]
    [[ "$output" == *"--recommendation and --rationale required"* ]]
}

# ---------- A7: help text mentions new flags ----------

@test "inception start: help text mentions --recommendation flag" {
    run show_inception_help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--recommendation"* ]]
    [[ "$output" == *"--rationale"* ]]
    [[ "$output" == *"--i-am-human"* ]]
    [[ "$output" == *"T-1715"* ]]
}
