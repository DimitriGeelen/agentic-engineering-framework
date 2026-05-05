#!/usr/bin/env bats
# T-1731: Human-AC tick guard — unit tests
#
# Closes G2 (path exemption non-diff-aware) from T-1729 meta-RCA.
# Tests the Python hook agents/context/check-human-ac-tick.py.
#
# Tests use a temporary task file with both Agent and Human ACs and
# simulate Edit/Write tool inputs targeting that file.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    HOOK_SH="$FRAMEWORK_ROOT/agents/context/check-human-ac-tick.sh"
    HOOK_PY="$FRAMEWORK_ROOT/agents/context/check-human-ac-tick.py"
    [ -f "$HOOK_SH" ] || skip "hook .sh wrapper not found"
    [ -f "$HOOK_PY" ] || skip "hook .py implementation not found"

    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.tasks/active" "$TEST_ROOT/.context/working"
    TASK_FILE="$TEST_ROOT/.tasks/active/T-9999-test.md"
    cat > "$TASK_FILE" <<'MD'
---
id: T-9999
name: "test"
status: started-work
workflow_type: build
---
# T-9999: test

## Acceptance Criteria

### Agent
- [ ] Agent AC one
- [ ] Agent AC two

### Human
- [ ] [REVIEW] Human AC one
- [ ] [REVIEW] Human AC two

## Verification

bats x
MD
    export PROJECT_ROOT="$TEST_ROOT"
    export CLAUDECODE=1
    unset FW_ALLOW_HUMAN_AC_TICK
}

teardown() {
    rm -rf "$TEST_ROOT" 2>/dev/null
}

# Helper: invoke hook with simulated Edit input
run_hook_edit() {
    local file="$1" old="$2" new="$3"
    local input
    input=$(python3 -c "
import json,sys
print(json.dumps({'tool_name':'Edit','tool_input':{'file_path':sys.argv[1],'old_string':sys.argv[2],'new_string':sys.argv[3],'replace_all':False}}))
" "$file" "$old" "$new")
    run bash "$HOOK_SH" <<< "$input"
}

run_hook_write() {
    local file="$1" content="$2"
    local input
    input=$(python3 -c "
import json,sys
print(json.dumps({'tool_name':'Write','tool_input':{'file_path':sys.argv[1],'content':sys.argv[2]}}))
" "$file" "$content")
    run bash "$HOOK_SH" <<< "$input"
}

# Tests ----------------------------------------------------------------

@test "Agent ticks Human AC ([ ] → [x]) — blocks under CLAUDECODE=1" {
    run_hook_edit "$TASK_FILE" \
        "- [ ] [REVIEW] Human AC one" \
        "- [x] [REVIEW] Human AC one"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "HUMAN-AC TICK BLOCKED"
    echo "$output" | grep -q "T-9999"
}

@test "Agent unticks Human AC ([x] → [ ]) — also blocks (any toggle)" {
    # First tick it (manually, not through hook)
    sed -i 's/- \[ \] \[REVIEW\] Human AC one/- [x] [REVIEW] Human AC one/' "$TASK_FILE"
    run_hook_edit "$TASK_FILE" \
        "- [x] [REVIEW] Human AC one" \
        "- [ ] [REVIEW] Human AC one"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "HUMAN-AC TICK BLOCKED"
}

@test "Agent ticks Agent AC — passes (different section)" {
    run_hook_edit "$TASK_FILE" \
        "- [ ] Agent AC one" \
        "- [x] Agent AC one"
    [ "$status" -eq 0 ]
}

@test "Edit unrelated to checkboxes (text change) — passes" {
    run_hook_edit "$TASK_FILE" \
        "## Verification" \
        "## Verification (updated)"
    [ "$status" -eq 0 ]
}

@test "Edit on non-task file (e.g. lib/foo.sh) — passes (out of scope)" {
    OUT_FILE="$TEST_ROOT/lib/foo.sh"
    mkdir -p "$(dirname "$OUT_FILE")"
    echo "- [ ] [REVIEW] not a task" > "$OUT_FILE"
    run_hook_edit "$OUT_FILE" "- [ ] [REVIEW] not a task" "- [x] [REVIEW] not a task"
    [ "$status" -eq 0 ]
}

@test "Override env FW_ALLOW_HUMAN_AC_TICK=1 — allows + logs to bypass log" {
    export FW_ALLOW_HUMAN_AC_TICK=1
    run_hook_edit "$TASK_FILE" \
        "- [ ] [REVIEW] Human AC one" \
        "- [x] [REVIEW] Human AC one"
    [ "$status" -eq 0 ]
    [ -f "$TEST_ROOT/.context/working/.gate-bypass-log.yaml" ]
    grep -q "FW_ALLOW_HUMAN_AC_TICK" "$TEST_ROOT/.context/working/.gate-bypass-log.yaml"
    grep -q "T-9999" "$TEST_ROOT/.context/working/.gate-bypass-log.yaml"
}

@test "No CLAUDECODE — advisory only, does not block" {
    unset CLAUDECODE
    run_hook_edit "$TASK_FILE" \
        "- [ ] [REVIEW] Human AC one" \
        "- [x] [REVIEW] Human AC one"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "advisory only"
}

@test "Task file with no Human section — passes" {
    cat > "$TASK_FILE" <<'MD'
---
id: T-9999
status: started-work
---
# T-9999

## Acceptance Criteria

### Agent
- [ ] Only an Agent AC
MD
    run_hook_edit "$TASK_FILE" \
        "- [ ] Only an Agent AC" \
        "- [x] Only an Agent AC"
    [ "$status" -eq 0 ]
}

@test "Write tool replacing entire file with toggled Human AC — blocks" {
    NEW_CONTENT='---
id: T-9999
---
## Acceptance Criteria

### Agent
- [ ] Agent AC one
- [ ] Agent AC two

### Human
- [x] [REVIEW] Human AC one
- [ ] [REVIEW] Human AC two
'
    run_hook_write "$TASK_FILE" "$NEW_CONTENT"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "HUMAN-AC TICK BLOCKED"
}

@test "MultiEdit with Human AC tick — blocks" {
    INPUT=$(python3 -c "
import json
print(json.dumps({
    'tool_name': 'MultiEdit',
    'tool_input': {
        'file_path': '$TASK_FILE',
        'edits': [
            {'old_string': '## Verification', 'new_string': '## Verification (updated)'},
            {'old_string': '- [ ] [REVIEW] Human AC one', 'new_string': '- [x] [REVIEW] Human AC one'}
        ]
    }
}))
")
    run bash "$HOOK_SH" <<< "$INPUT"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "HUMAN-AC TICK BLOCKED"
}

@test "Bash tool input — passes (out of scope, only Write/Edit/MultiEdit gated)" {
    INPUT='{"tool_name":"Bash","tool_input":{"command":"echo hi"}}'
    run bash "$HOOK_SH" <<< "$INPUT"
    [ "$status" -eq 0 ]
}

# Pin tests for settings.json + lib/init.sh wiring -------------------

@test "settings.json: check-human-ac-tick hook is registered (pin)" {
    python3 -c "
import json
d = json.load(open('$FRAMEWORK_ROOT/.claude/settings.json'))
matched = [h for h in d['hooks']['PreToolUse'] for inner in h.get('hooks',[]) if 'check-human-ac-tick' in inner.get('command','')]
assert matched, 'check-human-ac-tick hook missing from .claude/settings.json'
print('OK')
"
}

@test "lib/init.sh: hook generator includes check-human-ac-tick (source-of-truth)" {
    grep -q "hook check-human-ac-tick" "$FRAMEWORK_ROOT/lib/init.sh"
}
