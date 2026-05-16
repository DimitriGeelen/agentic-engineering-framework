#!/usr/bin/env bats
# T-1849: arc_id task-frontmatter validation guard — unit tests.
#
# Closes Q1 from arc-grooming inception (T-1846): hostage state where a task
# references a non-existent arc. PreToolUse hook check-arc-id.py refuses
# writes under agent control when arc_id is set + non-empty + does not
# resolve to .context/arcs/*.yaml. Empty/missing arc_id passes through.
# Predicated on T-1848 D-Immutability — valid refs stay valid forever.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    HOOK_SH="$FRAMEWORK_ROOT/agents/context/check-arc-id.sh"
    HOOK_PY="$FRAMEWORK_ROOT/agents/context/check-arc-id.py"
    [ -f "$HOOK_SH" ] || skip "hook .sh wrapper not found"
    [ -f "$HOOK_PY" ] || skip "hook .py implementation not found"

    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.tasks/active" "$TEST_ROOT/.context/arcs" "$TEST_ROOT/.context/working"

    # Fixture arcs: one slug-only (legacy form), one with arc-NNN id (T-1848).
    cat > "$TEST_ROOT/.context/arcs/dispatch-safety.yaml" <<'YAML'
id: arc-001
slug: dispatch-safety
name: "Dispatch safety"
status: in-progress
YAML

    cat > "$TEST_ROOT/.context/arcs/legacy-arc.yaml" <<'YAML'
id: legacy-arc
slug: legacy-arc
name: "Legacy arc"
status: in-progress
YAML

    export PROJECT_ROOT="$TEST_ROOT"
    export CLAUDECODE=1
    unset FW_ALLOW_ARC_ID_DRIFT
}

teardown() {
    rm -rf "$TEST_ROOT" 2>/dev/null
}

# Helper: invoke hook with simulated Write input (full content).
run_hook_write() {
    local file="$1" content="$2"
    local input
    input=$(python3 -c "
import json, sys
print(json.dumps({'tool_name': 'Write', 'tool_input': {'file_path': sys.argv[1], 'content': sys.argv[2]}}))
" "$file" "$content")
    run bash "$HOOK_SH" <<< "$input"
}

# --- Pass cases ---

@test "T-1849: empty arc_id passes through" {
    content="---
id: T-9999
name: test
arc_id:
---
# body
"
    run_hook_write "$TEST_ROOT/.tasks/active/T-9999-test.md" "$content"
    [ "$status" -eq 0 ]
}

@test "T-1849: missing arc_id field passes through" {
    content="---
id: T-9999
name: test
status: started-work
---
# body
"
    run_hook_write "$TEST_ROOT/.tasks/active/T-9999-test.md" "$content"
    [ "$status" -eq 0 ]
}

@test "T-1849: arc_id: null passes through" {
    content="---
id: T-9999
name: test
arc_id: null
---
# body
"
    run_hook_write "$TEST_ROOT/.tasks/active/T-9999-test.md" "$content"
    [ "$status" -eq 0 ]
}

@test "T-1849: arc_id = valid slug (dispatch-safety) passes" {
    content="---
id: T-9999
name: test
arc_id: dispatch-safety
---
# body
"
    run_hook_write "$TEST_ROOT/.tasks/active/T-9999-test.md" "$content"
    [ "$status" -eq 0 ]
}

@test "T-1849: arc_id = valid arc-NNN form (arc-001) passes" {
    content="---
id: T-9999
name: test
arc_id: arc-001
---
# body
"
    run_hook_write "$TEST_ROOT/.tasks/active/T-9999-test.md" "$content"
    [ "$status" -eq 0 ]
}

# --- Block cases ---

@test "T-1849: arc_id = nonexistent slug blocks under CLAUDECODE=1" {
    content="---
id: T-9999
name: test
arc_id: no-such-arc
---
# body
"
    run_hook_write "$TEST_ROOT/.tasks/active/T-9999-test.md" "$content"
    [ "$status" -eq 2 ]
    [[ "$output" == *"ARC_ID DOES NOT RESOLVE"* ]]
    [[ "$output" == *"no-such-arc"* ]]
}

@test "T-1849: arc_id = nonexistent arc-NNN (arc-999) blocks" {
    content="---
id: T-9999
name: test
arc_id: arc-999
---
# body
"
    run_hook_write "$TEST_ROOT/.tasks/active/T-9999-test.md" "$content"
    [ "$status" -eq 2 ]
    [[ "$output" == *"arc-999"* ]]
}

@test "T-1849: block message lists available arcs (slug form)" {
    content="---
id: T-9999
name: test
arc_id: bogus
---
# body
"
    run_hook_write "$TEST_ROOT/.tasks/active/T-9999-test.md" "$content"
    [ "$status" -eq 2 ]
    [[ "$output" == *"dispatch-safety"* ]]
    [[ "$output" == *"legacy-arc"* ]]
}

# --- Override / non-agent paths ---

@test "T-1849: FW_ALLOW_ARC_ID_DRIFT=1 lets invalid arc_id pass + logs" {
    content="---
id: T-9999
name: test
arc_id: bogus
---
# body
"
    FW_ALLOW_ARC_ID_DRIFT=1 run_hook_write "$TEST_ROOT/.tasks/active/T-9999-test.md" "$content"
    [ "$status" -eq 0 ]
    [[ "$output" == *"FW_ALLOW_ARC_ID_DRIFT=1"* ]]
    # Bypass log written
    [ -f "$TEST_ROOT/.context/working/.gate-bypass-log.yaml" ]
    grep -q "check-arc-id" "$TEST_ROOT/.context/working/.gate-bypass-log.yaml"
}

@test "T-1849: without CLAUDECODE / AI_AGENT, invalid arc_id is advisory only" {
    unset CLAUDECODE
    unset AI_AGENT
    content="---
id: T-9999
name: test
arc_id: bogus
---
# body
"
    run_hook_write "$TEST_ROOT/.tasks/active/T-9999-test.md" "$content"
    [ "$status" -eq 0 ]
}

# --- Path scoping ---

@test "T-1849: hook ignores non-task files" {
    content="---
arc_id: bogus
---
"
    run_hook_write "$TEST_ROOT/.context/working/something.md" "$content"
    [ "$status" -eq 0 ]
}

@test "T-1849: hook ignores files outside .tasks/{active,completed}/" {
    content="---
id: T-9999
arc_id: bogus
---
"
    run_hook_write "$TEST_ROOT/docs/T-9999-other.md" "$content"
    [ "$status" -eq 0 ]
}

# --- Tool name filtering ---

@test "T-1849: Bash tool passes through (only Write|Edit|MultiEdit guarded)" {
    input='{"tool_name":"Bash","tool_input":{"command":"echo hi"}}'
    run bash "$HOOK_SH" <<< "$input"
    [ "$status" -eq 0 ]
}

# --- Edit tool (substring substitution) ---

@test "T-1849: Edit that introduces invalid arc_id blocks" {
    cat > "$TEST_ROOT/.tasks/active/T-9999-test.md" <<'MD'
---
id: T-9999
name: test
status: started-work
---
# body
MD
    local input
    input=$(python3 -c "
import json
print(json.dumps({
    'tool_name': 'Edit',
    'tool_input': {
        'file_path': '$TEST_ROOT/.tasks/active/T-9999-test.md',
        'old_string': 'status: started-work',
        'new_string': 'status: started-work\narc_id: nope-not-a-real-arc',
        'replace_all': False
    }
}))
")
    run bash "$HOOK_SH" <<< "$input"
    [ "$status" -eq 2 ]
    [[ "$output" == *"nope-not-a-real-arc"* ]]
}

# --- Sanity ---

@test "T-1849: hook .py parses cleanly" {
    run python3 -m py_compile "$HOOK_PY"
    [ "$status" -eq 0 ]
}
