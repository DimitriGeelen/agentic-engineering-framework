#!/usr/bin/env bats
# T-2194 (T-2186 Slice 8): filing-time mirror of G-020 for inceptions.
# When the active inception has a ## Open Questions section with zero filed
# `- **IW-N:**` entries, source-file Write/Edit is blocked. Grandfather:
# inceptions with NO Open Questions section at all pass through.
# Bypass: FW_ALLOW_INCEPTION_OPEN_QUESTIONS_DRIFT=1 (logged Tier-2).

load ../test_helper

setup() {
    export FW_TEST_SKIP_TASK_CONTEXT_GATE=1  # T-4907: this file tests another gate; its fixture tasks carry no ## Context
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    unset FW_ALLOW_INCEPTION_OPEN_QUESTIONS_DRIFT
    mkdir -p "$TEST_TEMP_DIR/.context/working" "$TEST_TEMP_DIR/.tasks/active"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_TEMP_DIR/.framework.yaml"
    cat > "$TEST_TEMP_DIR/.context/working/focus.yaml" <<EOF
current_task: T-9001
focus_session: S-test
EOF
    cat > "$TEST_TEMP_DIR/.context/working/session.yaml" <<EOF
session_id: S-test
EOF
    HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    unset FW_ALLOW_INCEPTION_OPEN_QUESTIONS_DRIFT
}

_make_inception() {
    local id="$1" oq_body="$2"
    local path="$TEST_TEMP_DIR/.tasks/active/${id}-test.md"
    {
        echo "---"
        echo "id: $id"
        echo "status: started-work"
        echo "workflow_type: inception"
        echo "owner: agent"
        echo "horizon: now"
        echo "---"
        echo "# $id: Test"
        echo ""
        echo "## Acceptance Criteria"
        echo "### Agent"
        echo "- [ ] Some real AC"
        echo ""
        if [ -n "$oq_body" ]; then
            echo "## Open Questions"
            echo ""
            echo "$oq_body"
            echo ""
        fi
        echo "## Decision"
        echo "<!-- pending -->"
    } > "$path"
    echo "$path"
}

_run_hook_write() {
    local file_path="$1"
    python3 -c "import json,sys; print(json.dumps({'tool_name':'Write','tool_input':{'file_path': sys.argv[1]}}))" "$file_path" | bash "$HOOK"
}

@test "placeholder-only Open Questions: source-file write is blocked" {
    _make_inception T-9001 "<!-- template guidance only -->" >/dev/null
    run _run_hook_write "$TEST_TEMP_DIR/src/foo.py"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Inception"* ]]
    [[ "$output" == *"Open Questions"* ]]
    [[ "$output" == *"FW_ALLOW_INCEPTION_OPEN_QUESTIONS_DRIFT"* ]]
}

@test "filed Open Questions (≥1 IW-N): source-file write is allowed" {
    _make_inception T-9001 "- **IW-1: real question**
  confidence: 1" >/dev/null
    run _run_hook_write "$TEST_TEMP_DIR/src/foo.py"
    [ "$status" -eq 0 ]
}

@test "no Open Questions section at all: grandfathered, write allowed" {
    _make_inception T-9001 "" >/dev/null
    run _run_hook_write "$TEST_TEMP_DIR/src/foo.py"
    [ "$status" -eq 0 ]
}

@test "non-inception (build) active task: this gate does not fire" {
    local path="$TEST_TEMP_DIR/.tasks/active/T-9001-test.md"
    {
        echo "---"
        echo "id: T-9001"
        echo "status: started-work"
        echo "workflow_type: build"
        echo "owner: agent"
        echo "horizon: now"
        echo "---"
        echo "# T-9001"
        echo "## Acceptance Criteria"
        echo "### Agent"
        echo "- [ ] Real AC (not placeholder)"
        echo "## Open Questions"
        echo "<!-- empty -->"
    } > "$path"
    run _run_hook_write "$TEST_TEMP_DIR/src/foo.py"
    # build path runs through G-020 (which would pass — we wrote a real AC)
    # but the inception-Open-Questions block must not fire.
    [ "$status" -eq 0 ]
    [[ "$output" != *"Inception Open Questions"* ]] || false
}

@test "bypass FW_ALLOW_INCEPTION_OPEN_QUESTIONS_DRIFT=1: allows + writes log entry" {
    _make_inception T-9001 "<!-- empty -->" >/dev/null
    LOG_FILE="$TEST_TEMP_DIR/.context/working/.gate-bypass-log.yaml"
    : > "$LOG_FILE"
    FW_ALLOW_INCEPTION_OPEN_QUESTIONS_DRIFT=1 run _run_hook_write "$TEST_TEMP_DIR/src/foo.py"
    [ "$status" -eq 0 ]
    [[ "$output" == *"FW_ALLOW_INCEPTION_OPEN_QUESTIONS_DRIFT=1"* ]]
    # Log entry exists for this flag
    grep -q "FW_ALLOW_INCEPTION_OPEN_QUESTIONS_DRIFT" "$LOG_FILE"
    grep -q "check-active-task:inception-open-questions" "$LOG_FILE"
}

@test "exempt path (.tasks/) is allowed even when gate would fire" {
    _make_inception T-9001 "<!-- empty -->" >/dev/null
    # Editing the task file itself should be allowed (exempt path handled earlier)
    run _run_hook_write "$TEST_TEMP_DIR/.tasks/active/T-9001-test.md"
    [ "$status" -eq 0 ]
}

# T-4272 (greenfield run 3 F-44): C-001 (artifact first) and this gate used to
# name opposite first steps. The gate blocks docs/reports/ too, so the order is
# IW-1 first, research artifact second — and both texts must say so.
@test "T-4272: a docs/reports/ artifact write is blocked and the message names the artifact as the next step" {
    _make_inception T-9001 "<!-- empty -->" >/dev/null
    run _run_hook_write "$TEST_TEMP_DIR/docs/reports/T-9001-research.md"
    [ "$status" -eq 2 ]
    [[ "$output" == *"docs/reports/T-9001-"* ]]
    [[ "$output" == *"C-001"* ]]
}

@test "T-4272: CLAUDE.md and the consumer template put Open Questions before docs/reports/ in C-001" {
    local f item
    for f in "$FRAMEWORK_ROOT/CLAUDE.md" "$FRAMEWORK_ROOT/lib/templates/claude-project.md"; do
        item=$(grep -m1 'Research artifact first (C-001)' "$f")
        [ -n "$item" ]
        [[ "$item" == *"IW-1"*"docs/reports/"* ]] || { echo "C-001 item in $f does not put IW-1 before docs/reports/"; false; }
        [[ "$item" == *"T-2194"* ]] || { echo "C-001 item in $f does not name the T-2194 gate"; false; }
    done
}
