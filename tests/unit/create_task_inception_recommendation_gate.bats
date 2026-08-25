#!/usr/bin/env bats
# T-2207 (T-2204 Slice B') — create-task.sh CLI mirror of T-1716 filing gate.
#
# Closes the producer leaf for `fw task create --workflow inception`:
#   - T-1715/T-1716 ships --recommendation/--rationale on `fw inception start`
#   - T-2205 (Slice B) ships the Write/Edit PreToolUse hook
#   - T-2206 (Slice C) ships emit_review / emit_review_batch consumer block
#   - T-2207 (this slice) ships create-task.sh CLI parity
#
# Producer/consumer parity (T-1890): same env-var bypass name across all three
# producers — FW_ALLOW_EMPTY_RECOMMENDATION=1.
#
# Trusted-caller signal: do_inception_start sets FW_INCEPTION_PRE_GATED=1 when
# invoking create-task.sh, since it gates upstream. That signal is intentionally
# NOT logged Tier-2 (it's internal trusted-caller routing, not an agent override).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export TASKS_DIR="$TEST_TEMP_DIR/.tasks"
    export CONTEXT_DIR="$TEST_TEMP_DIR/.context"
    export NO_COLOR=1
    unset FW_ALLOW_EMPTY_RECOMMENDATION
    unset FW_INCEPTION_PRE_GATED
    unset CLAUDECODE
    unset AI_AGENT

    mkdir -p "$TASKS_DIR/active" "$TASKS_DIR/completed" "$TASKS_DIR/templates"
    mkdir -p "$CONTEXT_DIR/working"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"

    # Copy inception template — create-task.sh routes through it.
    cp "$FRAMEWORK_ROOT/.tasks/templates/inception.md" "$TASKS_DIR/templates/" 2>/dev/null \
        || cp "$FRAMEWORK_ROOT/.tasks/templates/zzz-default.md" "$TASKS_DIR/templates/inception.md" 2>/dev/null \
        || true
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Run create-task.sh with TASKS_DIR pointing at our temp dir.
run_create() {
    run "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" "$@"
}

# ──────────────────────────────────────────────────────────────────────────────
# Gate-firing path: $CLAUDECODE=1 + inception + no recommendation
# ──────────────────────────────────────────────────────────────────────────────

@test "build task: no Rec gate fires (no recommendation needed)" {
    export CLAUDECODE=1
    run_create --name "Build something" --type build --description "test" --owner agent
    [ "$status" -eq 0 ]
    [[ "$output" != *"BLOCKED: filing inception"* ]]
}

@test "inception under \$CLAUDECODE=1 without --recommendation BLOCKS" {
    export CLAUDECODE=1
    run_create --name "Explore something" --type inception --description "test" --owner human
    [ "$status" -eq 1 ]
    [[ "$output" == *"BLOCKED: filing inception"* ]]
    [[ "$output" == *"--recommendation"* ]]
    [[ "$output" == *"FW_ALLOW_EMPTY_RECOMMENDATION=1"* ]]
    [[ "$output" == *"--i-am-human"* ]]
    # Origin cross-refs must be present
    [[ "$output" == *"T-2207"* ]]
}

@test "inception under \$CLAUDECODE=1 with --recommendation but no --rationale BLOCKS" {
    export CLAUDECODE=1
    run_create --name "Explore" --type inception --description "test" --owner human \
        --recommendation GO
    [ "$status" -eq 1 ]
    [[ "$output" == *"BLOCKED: filing inception"* ]]
}

@test "invalid --recommendation value rejected with clear message" {
    export CLAUDECODE=1
    run_create --name "Bad rec" --type inception --description "test" --owner human \
        --recommendation MAYBE --rationale "test"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid --recommendation"* ]]
    [[ "$output" == *"MAYBE"* ]]
}

# ──────────────────────────────────────────────────────────────────────────────
# Pass-through paths
# ──────────────────────────────────────────────────────────────────────────────

@test "inception with --recommendation + --rationale PASSES + populates Rec block" {
    export CLAUDECODE=1
    run_create --name "Good filing" --type inception --description "test" --owner human \
        --recommendation GO \
        --rationale "Spike validated all four assumptions; build is mechanical"
    [ "$status" -eq 0 ]
    [[ "$output" != *"BLOCKED"* ]]
    # The new task file's ## Recommendation must be populated with our flags.
    local task_file
    task_file=$(ls "$TASKS_DIR/active/"T-*.md | head -1)
    [ -f "$task_file" ]
    grep -q "^\*\*Recommendation:\*\* GO" "$task_file"
    grep -q "Spike validated all four assumptions" "$task_file"
    # No template comment leakage after the populated block
    ! grep -q "<!-- Filled at completion of inception\|REQUIRED before fw inception decide" \
        <(awk '/^## Recommendation/,/^## /' "$task_file" | head -10)
}

@test "inception under \$CLAUDECODE=1 with --i-am-human PASSES + logs Tier-2" {
    export CLAUDECODE=1
    run_create --name "Human filing" --type inception --description "test" --owner human \
        --i-am-human
    [ "$status" -eq 0 ]
    [[ "$output" != *"BLOCKED"* ]]
    # Tier-2 log entry exists.
    local log="$CONTEXT_DIR/working/.gate-bypass-log.yaml"
    [ -f "$log" ]
    grep -q -- "--i-am-human" "$log"
    grep -q "create-task.sh" "$log"
    grep -q "Human filing" "$log"
}

@test "inception under \$CLAUDECODE=1 with FW_ALLOW_EMPTY_RECOMMENDATION=1 bypass PASSES + logs" {
    export CLAUDECODE=1
    FW_ALLOW_EMPTY_RECOMMENDATION=1 run_create --name "Bypass filing" \
        --type inception --description "test" --owner human
    [ "$status" -eq 0 ]
    [[ "$output" == *"NOTE: filing inception"* ]] || [[ "$output" == *"FW_ALLOW_EMPTY_RECOMMENDATION=1"* ]]
    # Tier-2 log entry exists.
    local log="$CONTEXT_DIR/working/.gate-bypass-log.yaml"
    [ -f "$log" ]
    grep -q "FW_ALLOW_EMPTY_RECOMMENDATION" "$log"
    grep -q "create-task.sh" "$log"
}

@test "inception with FW_INCEPTION_PRE_GATED=1 trusted-caller signal PASSES silently (no Tier-2 log)" {
    export CLAUDECODE=1
    # Trusted-caller path: do_inception_start sets this after its own gate.
    # The signal must NOT produce a bypass log entry (internal routing, not override).
    FW_INCEPTION_PRE_GATED=1 run_create --name "Pre-gated filing" \
        --type inception --description "test" --owner human
    [ "$status" -eq 0 ]
    [[ "$output" != *"BLOCKED"* ]]
    [[ "$output" != *"NOTE: filing inception"* ]]
    # No bypass-log entry created for the trusted-caller signal itself
    # (the upstream do_inception_start may log its own override separately).
    local log="$CONTEXT_DIR/working/.gate-bypass-log.yaml"
    if [ -f "$log" ]; then
        if grep -q "FW_INCEPTION_PRE_GATED" "$log"; then false; fi
        if grep -q "Pre-gated filing" "$log"; then false; fi
    fi
}

@test "inception without \$CLAUDECODE=1 PASSES without --recommendation (human terminal)" {
    unset CLAUDECODE
    run_create --name "Human terminal filing" --type inception --description "test" --owner human
    [ "$status" -eq 0 ]
    [[ "$output" != *"BLOCKED"* ]]
}

# ──────────────────────────────────────────────────────────────────────────────
# Regression: do_inception_start end-to-end still works (T-1716 path)
# ──────────────────────────────────────────────────────────────────────────────

@test "do_inception_start end-to-end: gate fires + Recommendation block injected via upstream path" {
    export CLAUDECODE=1
    export AGENTS_DIR="$FRAMEWORK_ROOT/agents"
    export FW_LIB_DIR="$FRAMEWORK_ROOT/lib"
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/paths.sh"
    source "$FRAMEWORK_ROOT/lib/inception.sh"

    # No flags → blocked upstream by T-1716 (not by my new gate).
    run do_inception_start "Upstream blocked" --owner human
    [ "$status" -eq 1 ]
    [[ "$output" == *"--recommendation and --rationale required"* ]]
}

@test "do_inception_start: with flags injects Recommendation via upstream — gate does NOT double-fire" {
    export CLAUDECODE=1
    export AGENTS_DIR="$FRAMEWORK_ROOT/agents"
    export FW_LIB_DIR="$FRAMEWORK_ROOT/lib"
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/paths.sh"
    source "$FRAMEWORK_ROOT/lib/inception.sh"

    # This must NOT trip the T-2207 gate (FW_INCEPTION_PRE_GATED=1 silences it).
    # The block goes via _inject_recommendation_block, not our injection path.
    run do_inception_start "End-to-end fixture" --owner human \
        --recommendation GO --rationale "Evidence cited"
    [ "$status" -eq 0 ]
    [[ "$output" != *"BLOCKED: filing inception"* ]]
    local task_file
    task_file=$(ls "$TASKS_DIR/active/"T-*.md | head -1)
    [ -f "$task_file" ]
    grep -q "End-to-end fixture" "$task_file"
}
