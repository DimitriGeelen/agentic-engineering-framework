#!/usr/bin/env bats
# T-3412: .gate-bypass-log.yaml corruption — two independent root causes,
# both found while re-verifying T-3370's still-open A2 finding (SEQ-T3411 r1).
#
# Bug A (check-active-task.sh, two call sites): the bypassed BASH_CMD is
# truncated with `head -c 200` — a raw BYTE offset with no UTF-8 boundary
# awareness. A multi-byte character (e.g. a smart quote from a `git commit -m`
# message) straddling byte 200 gets its lead byte kept and its continuation
# byte(s) dropped, embedding an incomplete UTF-8 sequence in a single-quoted
# YAML scalar. Fix: decode with errors="ignore" after the byte truncation so
# an incomplete trailing sequence is dropped, not kept.
#
# Bug B (create-task.sh + lib/inception.sh, sibling call sites): the free-text
# inception title is interpolated into a single-quoted YAML scalar with no
# escaping. An embedded apostrophe terminates the scalar early and the rest of
# the title is parsed as unexpected YAML, breaking the whole file's parse two
# lines later. Fix: double embedded single quotes (same T-1861 idiom already
# used by agents/task-create/update-task.sh:log_gate_bypass and others).
#
# Both bugs were confirmed live in .context/working/.gate-bypass-log.yaml
# (repaired as part of this task, not by these tests — these tests are
# hermetic, against a throwaway PROJECT_ROOT/CONTEXT_DIR).

load ../test_helper

# ── Bug A: check-active-task.sh FW_SWITCH_FOCUS=1 command-field truncation ──

setup_check_active_task() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    mkdir -p "$TEST_TEMP_DIR/.context/working" \
             "$TEST_TEMP_DIR/.tasks/active" \
             "$TEST_TEMP_DIR/.tasks/completed"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_TEMP_DIR/.framework.yaml"
    cat > "$TEST_TEMP_DIR/.context/working/focus.yaml" <<EOF
current_task: T-8888
EOF
    cat > "$TEST_TEMP_DIR/.tasks/active/T-8888-stub.md" <<EOF
---
id: T-8888
name: stub
status: started-work
workflow_type: build
owner: agent
---
EOF
    HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
}

teardown() {
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_run_hook_bash() {
    local cmd="$1"
    local json
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Bash','tool_input':{'command': sys.argv[1]}}))" "$cmd")
    echo "$json" | bash "$HOOK"
}

@test "T-3412 FIX: multi-byte UTF-8 char straddling the 200-byte truncation boundary still yields a parseable log" {
    setup_check_active_task
    # Focus is T-8888; target a different task (T-8889) so drift fires, with
    # FW_SWITCH_FOCUS=1 as the bypass mechanism. Pad with 100 ASCII bytes then
    # 30 repetitions of U+2019 (3 bytes each, 90 bytes) — for ANY reasonable
    # prefix length up to ~100 bytes, at least one full 3-byte sequence in that
    # 90-byte run straddles absolute byte 200, reproducing the real corruption
    # without hand-computing an exact offset (robust to prefix text changing).
    local pad_ascii filler quote cmd
    pad_ascii=$(printf 'a%.0s' $(seq 1 100))
    filler=$(python3 -c "print('’' * 30, end='')")
    quote="'"
    cmd="FW_SWITCH_FOCUS=1 bin/fw task update T-8889 --note ${quote}${pad_ascii}${filler}tail${quote}"

    run _run_hook_bash "$cmd"

    local log="$TEST_TEMP_DIR/.context/working/.gate-bypass-log.yaml"
    [ -f "$log" ]
    # The whole file must remain valid YAML/UTF-8 — this is what broke live.
    run python3 -c "import yaml; yaml.safe_load(open('$log'))"
    [ "$status" -eq 0 ]
    # And the bypass really was logged (not silently skipped).
    grep -q "flag: 'FW_SWITCH_FOCUS=1'" "$log"
    grep -q "target: 'T-8889'" "$log"
}

@test "T-3412 CONTROL: an all-ASCII FW_SWITCH_FOCUS=1 command still logs a parseable, unmangled entry" {
    setup_check_active_task
    run _run_hook_bash "FW_SWITCH_FOCUS=1 bin/fw task update T-8890 --note 'plain ascii note'"

    local log="$TEST_TEMP_DIR/.context/working/.gate-bypass-log.yaml"
    [ -f "$log" ]
    run python3 -c "import yaml; yaml.safe_load(open('$log'))"
    [ "$status" -eq 0 ]
    grep -q "target: 'T-8890'" "$log"
    grep -q "plain ascii note" "$log"
}

# ── Bug B: free-text title with an embedded apostrophe ──

# ---------- B1: create-task.sh CLI (FW_ALLOW_EMPTY_RECOMMENDATION path) ----------

setup_create_task() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export TASKS_DIR="$TEST_TEMP_DIR/.tasks"
    export CONTEXT_DIR="$TEST_TEMP_DIR/.context"
    export NO_COLOR=1
    unset FW_ALLOW_EMPTY_RECOMMENDATION FW_INCEPTION_PRE_GATED CLAUDECODE AI_AGENT
    mkdir -p "$TASKS_DIR/active" "$TASKS_DIR/completed" "$TASKS_DIR/templates"
    mkdir -p "$CONTEXT_DIR/working"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    cp "$FRAMEWORK_ROOT/.tasks/templates/inception.md" "$TASKS_DIR/templates/" 2>/dev/null \
        || cp "$FRAMEWORK_ROOT/.tasks/templates/zzz-default.md" "$TASKS_DIR/templates/inception.md" 2>/dev/null \
        || true
}

@test "T-3412 FIX: create-task.sh NAME with an apostrophe still yields a parseable bypass log" {
    setup_create_task
    export CLAUDECODE=1
    FW_ALLOW_EMPTY_RECOMMENDATION=1 run "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" \
        --name "Operator's filing: don't lose this apostrophe" \
        --type inception --description "test" --owner human
    [ "$status" -eq 0 ]

    local log="$CONTEXT_DIR/working/.gate-bypass-log.yaml"
    [ -f "$log" ]
    run python3 -c "import yaml; yaml.safe_load(open('$log'))"
    [ "$status" -eq 0 ]
    grep -q "FW_ALLOW_EMPTY_RECOMMENDATION" "$log"
    # The doubled-quote escaping is present in the raw file (YAML single-quote rule).
    grep -q "Operator''s filing" "$log"
}

# ---------- B2: lib/inception.sh do_inception_start (--i-am-human path) ----------

setup_inception_start() {
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
    cp "$FRAMEWORK_ROOT/.tasks/templates/inception.md" \
       "$TEST_TEMP_DIR/.tasks/templates/inception.md"
    cp "$FRAMEWORK_ROOT/.tasks/templates/default.md" \
       "$TEST_TEMP_DIR/.tasks/templates/default.md" 2>/dev/null || true
}

@test "T-3412 FIX: do_inception_start NAME with an apostrophe still yields a parseable bypass log" {
    setup_inception_start
    CLAUDECODE=1 run do_inception_start "It's a trap: apostrophe in the title" --i-am-human
    [ "$status" -eq 0 ]

    local log="$TEST_TEMP_DIR/.context/working/.gate-bypass-log.yaml"
    [ -f "$log" ]
    run python3 -c "import yaml; yaml.safe_load(open('$log'))"
    [ "$status" -eq 0 ]
    grep -q "flag: '--i-am-human'" "$log"
    grep -q "It''s a trap" "$log"
}
