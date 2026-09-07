#!/usr/bin/env bats
# T-3299 (OBS-353): a block message is an EXECUTABLE CONTRACT.
#
# The G-020 build-readiness gate blocks everything that falls through to it
# while the focused build task has placeholder ACs — and, before this task,
# that included BOTH remedies its own block message prescribed:
#
#   remedy "edit the task file's ACs"  — refused in every SHELL form (heredoc,
#                                        sed -i, any redirect all match the
#                                        write-pattern scan); only the
#                                        Write/Edit TOOL route worked, and the
#                                        message never mentioned it.
#   remedy "fw task update --type …"   — refused by the gate that printed it:
#                                        `update` is not a safe-listed task
#                                        sub-verb, nothing upstream admits it,
#                                        so it fell through to G-020's exit 2.
#
# An agent whose only write surface was Bash had no legal move at all
# (measured live, 2026-08-29, T-3216 run). The message was authored from an
# UNBLOCKED shell; its remedies were never run from inside the blocked state.
#
# This suite is the rail: it constructs the gate-firing state, captures the
# block message, EXTRACTS the remedy command lines from that very output, and
# executes them through the hook — so if the message and the allowlist ever
# drift apart again, this goes red. Control legs pin that the gate itself is
# not weakened: ordinary source writes, shell writes to the task file, and
# non-metadata / write-carrying / drifting task updates all stay blocked.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export CLAUDECODE=1  # hook enforces (vs advisory) under agent control
    mkdir -p "$TEST_TEMP_DIR/.context/working" "$TEST_TEMP_DIR/.tasks/active" \
             "$TEST_TEMP_DIR/lib"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_TEMP_DIR/.framework.yaml"

    # THE WEDGED SHAPE: focused build task, started-work, template placeholder
    # ACs. This is exactly what the T-3215/T-3216 focus-steal produced.
    cat > "$TEST_TEMP_DIR/.tasks/active/T-1300-wedged.md" <<'EOF'
---
id: T-1300
status: started-work
workflow_type: build
---
# T-1300

## Acceptance Criteria

### Agent
- [ ] [First criterion]
- [ ] [Second criterion]
EOF
    cat > "$TEST_TEMP_DIR/.context/working/focus.yaml" <<'EOF'
current_task: T-1300
focus_session: S-test-t3299
EOF

    # Drift target for the control leg.
    cat > "$TEST_TEMP_DIR/.tasks/active/T-1400-other.md" <<'EOF'
---
id: T-1400
status: started-work
workflow_type: build
---
# T-1400
## Acceptance Criteria
- [ ] real criterion
EOF

    HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

_run_hook_bash() {
    local cmd="$1"
    local json
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Bash','tool_input':{'command': sys.argv[1]}}))" "$cmd")
    echo "$json" | bash "$HOOK"
}

_run_hook_tool() {
    local tool="$1" path="$2"
    local json
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_name':sys.argv[1],'tool_input':{'file_path': sys.argv[2], 'content':'x'}}))" "$tool" "$path")
    echo "$json" | bash "$HOOK"
}

# ── The gate itself still fires (controls first — without these, "remedies
#    pass" and "gate is gone" are the same green) ─────────────────────────────

@test "t3299 control: ordinary source write via Bash is blocked with the G-020 message" {
    run _run_hook_bash "echo x > $TEST_TEMP_DIR/lib/config.sh"
    [ "$status" -eq 2 ]
    [[ "$output" == *"G-020"* ]]
    [[ "$output" == *"placeholder/missing ACs"* ]]
}

@test "t3299 control: ordinary source write via the Write tool is blocked" {
    run _run_hook_tool "Write" "$TEST_TEMP_DIR/lib/config.sh"
    [ "$status" -eq 2 ]
    [[ "$output" == *"G-020"* ]]
}

# ── Remedy: metadata-only task update, EXTRACTED from the block output ───────

@test "t3299: remedy '--type inception' extracted verbatim from the block message is not blocked" {
    run _run_hook_bash "echo x > $TEST_TEMP_DIR/lib/config.sh"
    [ "$status" -eq 2 ]
    local remedy
    remedy=$(printf '%s\n' "$output" | grep -E 'task update T-1300 --type inception' | sed 's/^[[:space:]]*//')
    [ -n "$remedy" ]
    run _run_hook_bash "$remedy"
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-3299"* ]]  # the allow is the deliberate T-3299 exemption, not an accident
}

@test "t3299: remedy '--horizon later' extracted verbatim from the block message is not blocked" {
    run _run_hook_bash "echo x > $TEST_TEMP_DIR/lib/config.sh"
    [ "$status" -eq 2 ]
    local remedy
    remedy=$(printf '%s\n' "$output" | grep -E 'task update T-1300 --horizon later' | sed 's/^[[:space:]]*//')
    [ -n "$remedy" ]
    run _run_hook_bash "$remedy"
    [ "$status" -eq 0 ]
}

@test "t3299: bin/fw-prefixed and cd-chained metadata updates also pass" {
    run _run_hook_bash "bin/fw task update T-1300 --type inception"
    [ "$status" -eq 0 ]
    run _run_hook_bash "cd $TEST_TEMP_DIR && bin/fw task update T-1300 --horizon later --reason parked"
    [ "$status" -eq 0 ]
}

# ── Remedy: task-file AC editing via the Write/Edit TOOL ─────────────────────

@test "t3299: the Edit tool on the wedged task's own file is not blocked (.tasks/* exempt)" {
    run _run_hook_tool "Edit" "$TEST_TEMP_DIR/.tasks/active/T-1300-wedged.md"
    [ "$status" -eq 0 ]
    run _run_hook_tool "Write" "$TEST_TEMP_DIR/.tasks/active/T-1300-wedged.md"
    [ "$status" -eq 0 ]
}

@test "t3299: the block message states the Edit-tool route and that shell writes stay blocked" {
    # The printed contract must match reality: route 1 is the Write/Edit TOOL,
    # and the message must say shell writes to the task file remain blocked.
    run _run_hook_bash "echo x > $TEST_TEMP_DIR/lib/config.sh"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Write/Edit TOOL"* ]]
    [[ "$output" == *"stay blocked"* ]]
}

# ── The gate is NOT weakened: everything else stays red ──────────────────────

@test "t3299 control: SHELL write to the wedged task's own file stays blocked" {
    run _run_hook_bash "sed -i 's/a/b/' $TEST_TEMP_DIR/.tasks/active/T-1300-wedged.md"
    [ "$status" -eq 2 ]
    run _run_hook_bash "echo '- [ ] real AC' >> $TEST_TEMP_DIR/.tasks/active/T-1300-wedged.md"
    [ "$status" -eq 2 ]
}

@test "t3299 control: non-metadata task update stays blocked" {
    run _run_hook_bash "bin/fw task update T-1300 --add-tag ui"
    [ "$status" -eq 2 ]
    run _run_hook_bash "bin/fw task update T-1300 --owner human"
    [ "$status" -eq 2 ]
}

@test "t3299 control: metadata update carrying a write pattern or unsafe clause stays blocked" {
    run _run_hook_bash "bin/fw task update T-1300 --type inception > /tmp/out"
    [ "$status" -eq 2 ]
    run _run_hook_bash "bin/fw task update T-1300 --type inception && rm -rf /tmp/x"
    [ "$status" -eq 2 ]
}

@test "t3299 control: =-attached value stays blocked (downstream parser rejects it — T-1890 parity)" {
    run _run_hook_bash "bin/fw task update T-1300 --type=inception"
    [ "$status" -eq 2 ]
}

@test "t3299 control: metadata update targeting a DIFFERENT task hits the drift gate first" {
    run _run_hook_bash "bin/fw task update T-1400 --type inception"
    [ "$status" -eq 2 ]
    [[ "$output" == *"FOCUS-DRIFT"* ]]
}

# ── Downstream parity (L-399 / T-1890): every flag the predicate admits has a
#    real parser arm in update-task.sh, so gate-allows → parser-accepts ───────

@test "t3299: update-task.sh parses every admitted metadata flag" {
    local parser="$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
    grep -q -- '--type|-t)' "$parser"
    grep -q -- '--horizon)' "$parser"
    grep -q -- '--status|-s)' "$parser"
    grep -q -- '--reason|-r)' "$parser"
    grep -q -- '--switch-focus)' "$parser"
}
