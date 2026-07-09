#!/usr/bin/env bats
# T-2517: active<->completed same-id task duplicate write-time guard (T-2121 prong 1).
#
# PreToolUse hook check-active-completed-dup.py refuses a Write that would
# CREATE .tasks/completed/T-NNNN-*.md while .tasks/active/T-NNNN-*.md already
# exists (and vice-versa). Edits to already-existing files never trigger it,
# and the legitimate `fw task update --status work-completed` git-mv path
# never reaches the hook at all (it moves the file via a Bash subprocess).

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    HOOK_SH="$FRAMEWORK_ROOT/agents/context/check-active-completed-dup.sh"
    HOOK_PY="$FRAMEWORK_ROOT/agents/context/check-active-completed-dup.py"
    [ -f "$HOOK_SH" ] || skip "hook .sh wrapper not found"
    [ -f "$HOOK_PY" ] || skip "hook .py implementation not found"

    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.tasks/active" "$TEST_ROOT/.tasks/completed" "$TEST_ROOT/.context/working"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_ROOT/.framework.yaml"

    export PROJECT_ROOT="$TEST_ROOT"
    export CONTEXT_DIR="$TEST_ROOT/.context"
    export CLAUDECODE=1
    unset FW_ALLOW_ACTIVE_COMPLETED_DUP
}

teardown() {
    rm -rf "$TEST_ROOT" 2>/dev/null
}

# Helper: invoke hook with simulated Write input (full content, new file).
run_hook_write() {
    local file="$1" content="$2"
    local input
    input=$(python3 -c "
import json, sys
print(json.dumps({'tool_name': 'Write', 'tool_input': {'file_path': sys.argv[1], 'content': sys.argv[2]}}))
" "$file" "$content")
    run bash "$HOOK_SH" <<< "$input"
}

_minimal_content() {
    local id="$1"
    echo "---
id: ${id}
name: test
status: started-work
---
# body
"
}

# --- Block cases ---

@test "T-2517: Write creating completed/T-X while active/T-X exists → BLOCKED" {
    cat > "$TEST_ROOT/.tasks/active/T-9001-existing.md" <<'MD'
---
id: T-9001
name: existing active copy
status: started-work
---
# body
MD
    run_hook_write "$TEST_ROOT/.tasks/completed/T-9001-existing.md" "$(_minimal_content T-9001)"
    [ "$status" -eq 2 ]
    [[ "$output" == *"ACTIVE/COMPLETED DUPLICATE"* ]]
    [[ "$output" == *"T-9001"* ]]
}

@test "T-2517: Write creating active/T-X while completed/T-X exists → BLOCKED (reverse direction)" {
    cat > "$TEST_ROOT/.tasks/completed/T-9002-existing.md" <<'MD'
---
id: T-9002
name: existing completed copy
status: work-completed
---
# body
MD
    run_hook_write "$TEST_ROOT/.tasks/active/T-9002-existing.md" "$(_minimal_content T-9002)"
    [ "$status" -eq 2 ]
    [[ "$output" == *"ACTIVE/COMPLETED DUPLICATE"* ]]
    [[ "$output" == *"T-9002"* ]]
}

@test "T-2517: block message names the override mechanism" {
    cat > "$TEST_ROOT/.tasks/active/T-9003-existing.md" <<'MD'
---
id: T-9003
name: existing
status: started-work
---
# body
MD
    run_hook_write "$TEST_ROOT/.tasks/completed/T-9003-existing.md" "$(_minimal_content T-9003)"
    [ "$status" -eq 2 ]
    [[ "$output" == *"FW_ALLOW_ACTIVE_COMPLETED_DUP=1"* ]]
    [[ "$output" == *"fw task update T-9003 --status work-completed"* ]]
}

# --- Pass cases ---

@test "T-2517: Write creating brand-new task (no sibling copy) → PASSES" {
    run_hook_write "$TEST_ROOT/.tasks/active/T-9010-fresh.md" "$(_minimal_content T-9010)"
    [ "$status" -eq 0 ]
}

@test "T-2517: Write overwriting an already-existing file at the SAME path → PASSES (not a creation)" {
    cat > "$TEST_ROOT/.tasks/active/T-9011-existing.md" <<'MD'
---
id: T-9011
name: existing
status: started-work
---
# body
MD
    # No sibling copy in completed/ — but even with one, editing the file at
    # its own existing path is never treated as "creating" a duplicate.
    run_hook_write "$TEST_ROOT/.tasks/active/T-9011-existing.md" "$(_minimal_content T-9011)"
    [ "$status" -eq 0 ]
}

@test "T-2517: Edit tool on an already-existing completed/T-X copy (cleanup) → PASSES" {
    cat > "$TEST_ROOT/.tasks/active/T-9012-existing.md" <<'MD'
---
id: T-9012
name: existing active
status: started-work
---
# body
MD
    cat > "$TEST_ROOT/.tasks/completed/T-9012-existing.md" <<'MD'
---
id: T-9012
name: existing completed
status: work-completed
---
# body
MD
    local input
    input=$(python3 -c "
import json
print(json.dumps({
    'tool_name': 'Edit',
    'tool_input': {
        'file_path': '$TEST_ROOT/.tasks/completed/T-9012-existing.md',
        'old_string': 'status: work-completed',
        'new_string': 'status: work-completed\n# cleanup note',
        'replace_all': False
    }
}))
")
    run bash "$HOOK_SH" <<< "$input"
    [ "$status" -eq 0 ]
}

# --- Override / non-agent paths ---

@test "T-2517: FW_ALLOW_ACTIVE_COMPLETED_DUP=1 lets duplicate write pass + logs" {
    cat > "$TEST_ROOT/.tasks/active/T-9020-existing.md" <<'MD'
---
id: T-9020
name: existing
status: started-work
---
# body
MD
    FW_ALLOW_ACTIVE_COMPLETED_DUP=1 run_hook_write "$TEST_ROOT/.tasks/completed/T-9020-existing.md" "$(_minimal_content T-9020)"
    [ "$status" -eq 0 ]
    [[ "$output" == *"FW_ALLOW_ACTIVE_COMPLETED_DUP=1"* ]]
    [ -f "$TEST_ROOT/.context/working/.gate-bypass-log.yaml" ]
    grep -q "check-active-completed-dup" "$TEST_ROOT/.context/working/.gate-bypass-log.yaml"
}

@test "T-2517: without CLAUDECODE / AI_AGENT, duplicate write is advisory only" {
    unset CLAUDECODE
    unset AI_AGENT
    cat > "$TEST_ROOT/.tasks/active/T-9021-existing.md" <<'MD'
---
id: T-9021
name: existing
status: started-work
---
# body
MD
    run_hook_write "$TEST_ROOT/.tasks/completed/T-9021-existing.md" "$(_minimal_content T-9021)"
    [ "$status" -eq 0 ]
}

# --- Path scoping ---

@test "T-2517: hook ignores non-task files" {
    run_hook_write "$TEST_ROOT/.context/working/something.md" "arc_id: bogus"
    [ "$status" -eq 0 ]
}

@test "T-2517: hook ignores files outside .tasks/{active,completed}/" {
    mkdir -p "$TEST_ROOT/docs"
    run_hook_write "$TEST_ROOT/docs/T-9022-other.md" "$(_minimal_content T-9022)"
    [ "$status" -eq 0 ]
}

@test "T-2517: Bash tool passes through (only Write|Edit|MultiEdit guarded)" {
    input='{"tool_name":"Bash","tool_input":{"command":"echo hi"}}'
    run bash "$HOOK_SH" <<< "$input"
    [ "$status" -eq 0 ]
}

# --- End-to-end: legitimate git-mv completion path is NOT blocked ---

@test "T-2517: fw task update --status work-completed completes cleanly with hook registered" {
    cd "$TEST_ROOT"
    cat > "$TEST_ROOT/.tasks/active/T-9030-e2e.md" <<EOF
---
id: T-9030
name: "E2E completion"
description: test
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
date_finished: null
---

# T-9030: E2E completion

## Context
test.

## Acceptance Criteria

### Agent
- [x] Done

## Verification

echo ok

## Recommendation
**Recommendation:** GO
**Rationale:** test
**Evidence:** test
EOF
    run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9030 \
        --status work-completed --skip-acceptance-criteria
    [ "$status" -eq 0 ]
    [ -f "$TEST_ROOT/.tasks/completed/T-9030-e2e.md" ]
    [ ! -f "$TEST_ROOT/.tasks/active/T-9030-e2e.md" ]
}

# --- Sanity ---

@test "T-2517: hook .py parses cleanly" {
    run python3 -m py_compile "$HOOK_PY"
    [ "$status" -eq 0 ]
}
