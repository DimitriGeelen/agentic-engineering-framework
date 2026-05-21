#!/usr/bin/env bats
# T-1984: check-inception-decisions PreToolUse hook — unit tests.
#
# Covers:
#   - inception_decisions: structural validation (shape/id/text errors)
#   - unlocks_inception_decision: format + reference validation
#   - Override via FW_ALLOW_INCEPTION_DECISIONS_DRIFT=1
#   - Agent-vs-human control (CLAUDECODE=1 blocks, unset is advisory)
#   - Pass-through for non-task files, non-matching tools

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    HOOK_SH="$FRAMEWORK_ROOT/agents/context/check-inception-decisions.sh"
    HOOK_PY="$FRAMEWORK_ROOT/agents/context/check-inception-decisions.py"
    [ -f "$HOOK_SH" ] || skip "hook .sh wrapper not found"
    [ -f "$HOOK_PY" ] || skip "hook .py implementation not found"

    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.tasks/active" "$TEST_ROOT/.tasks/completed" "$TEST_ROOT/.context/working"

    export PROJECT_ROOT="$TEST_ROOT"
    export CLAUDECODE=1
    unset FW_ALLOW_INCEPTION_DECISIONS_DRIFT
}

teardown() {
    rm -rf "$TEST_ROOT" 2>/dev/null
}

# ── helpers ───────────────────────────────────────────────────────────────────

run_hook_write() {
    local file="$1" content="$2"
    local input
    input=$(python3 -c "
import json, sys
print(json.dumps({'tool_name': 'Write', 'tool_input': {'file_path': sys.argv[1], 'content': sys.argv[2]}}))
" "$file" "$content")
    run bash "$HOOK_SH" <<< "$input"
}

run_hook_edit() {
    local file="$1" old_str="$2" new_str="$3"
    local input
    input=$(python3 -c "
import json, sys
print(json.dumps({'tool_name': 'Edit', 'tool_input': {
    'file_path': sys.argv[1],
    'old_string': sys.argv[2],
    'new_string': sys.argv[3],
    'replace_all': False
}}))
" "$file" "$old_str" "$new_str")
    run bash "$HOOK_SH" <<< "$input"
}

make_inception_task_with_decisions() {
    local file="$1"
    shift
    # Each remaining arg is "id|ships_in" pair
    local decisions=""
    for pair in "$@"; do
        local id="${pair%%|*}"
        local ships_in="${pair##*|}"
        decisions="${decisions}  - id: ${id}
    text: 'Decision for ${id}'
    ships_in: ${ships_in}
"
    done
    cat > "$file" <<EOF
---
id: T-9990
name: "test inception"
workflow_type: inception
inception_decisions:
${decisions}
---
# body
EOF
}

# ── pass-through cases ────────────────────────────────────────────────────────

@test "T-1984: no inception_decisions field passes through" {
    local file="$TEST_ROOT/.tasks/active/T-9990-test.md"
    local content="---
id: T-9990
name: test
workflow_type: inception
---
# body
"
    run_hook_write "$file" "$content"
    [ "$status" -eq 0 ]
}

@test "T-1984: inception_decisions empty list passes through" {
    local file="$TEST_ROOT/.tasks/active/T-9990-test.md"
    local content="---
id: T-9990
name: test
workflow_type: inception
inception_decisions: []
---
# body
"
    run_hook_write "$file" "$content"
    [ "$status" -eq 0 ]
}

@test "T-1984: valid single inception_decisions entry passes" {
    local file="$TEST_ROOT/.tasks/active/T-9990-test.md"
    local content="---
id: T-9990
name: test
workflow_type: inception
inception_decisions:
  - id: my-decision
    text: 'Do the thing'
    ships_in: lib/foo.py
---
# body
"
    run_hook_write "$file" "$content"
    [ "$status" -eq 0 ]
}

@test "T-1984: valid task-id shape passes" {
    local file="$TEST_ROOT/.tasks/active/T-9990-test.md"
    local content="---
id: T-9990
name: test
workflow_type: inception
inception_decisions:
  - id: task-ship
    text: 'Ship via task'
    ships_in: T-1000
---
# body
"
    run_hook_write "$file" "$content"
    [ "$status" -eq 0 ]
}

@test "T-1984: valid deferred shape passes" {
    local file="$TEST_ROOT/.tasks/active/T-9990-test.md"
    local content="---
id: T-9990
name: test
workflow_type: inception
inception_decisions:
  - id: deferred-ship
    text: 'Deferred'
    ships_in: deferred:T-2000
---
# body
"
    run_hook_write "$file" "$content"
    [ "$status" -eq 0 ]
}

# ── block cases — inception_decisions structural errors ───────────────────────

@test "T-1984: unknown ships_in shape blocks under CLAUDECODE=1" {
    local file="$TEST_ROOT/.tasks/active/T-9990-test.md"
    local content="---
id: T-9990
name: test
workflow_type: inception
inception_decisions:
  - id: bad-shape
    text: 'Oops'
    ships_in: justabareword
---
# body
"
    run_hook_write "$file" "$content"
    [ "$status" -eq 2 ]
    [[ "$output" == *"INCEPTION_DECISIONS STRUCTURAL ERROR"* ]]
    [[ "$output" == *"justabareword"* ]]
}

@test "T-1984: duplicate id blocks" {
    local file="$TEST_ROOT/.tasks/active/T-9990-test.md"
    local content="---
id: T-9990
name: test
workflow_type: inception
inception_decisions:
  - id: dup
    text: 'First'
    ships_in: T-100
  - id: dup
    text: 'Second'
    ships_in: T-101
---
# body
"
    run_hook_write "$file" "$content"
    [ "$status" -eq 2 ]
    [[ "$output" == *"duplicate id"* ]]
}

@test "T-1984: missing text field blocks" {
    local file="$TEST_ROOT/.tasks/active/T-9990-test.md"
    local content="---
id: T-9990
name: test
workflow_type: inception
inception_decisions:
  - id: no-text
    ships_in: T-100
---
# body
"
    run_hook_write "$file" "$content"
    [ "$status" -eq 2 ]
}

@test "T-1984: non-kebab id blocks" {
    local file="$TEST_ROOT/.tasks/active/T-9990-test.md"
    local content="---
id: T-9990
name: test
workflow_type: inception
inception_decisions:
  - id: BadId
    text: 'Oops'
    ships_in: T-100
---
# body
"
    run_hook_write "$file" "$content"
    [ "$status" -eq 2 ]
}

# ── override ──────────────────────────────────────────────────────────────────

@test "T-1984: FW_ALLOW_INCEPTION_DECISIONS_DRIFT=1 overrides structural block + logs" {
    local file="$TEST_ROOT/.tasks/active/T-9990-test.md"
    local content="---
id: T-9990
name: test
workflow_type: inception
inception_decisions:
  - id: bad
    text: 'bad'
    ships_in: justabareword
---
"
    FW_ALLOW_INCEPTION_DECISIONS_DRIFT=1 run_hook_write "$file" "$content"
    [ "$status" -eq 0 ]
    # Bypass log written
    [ -f "$TEST_ROOT/.context/working/.gate-bypass-log.yaml" ]
    grep -q "check-inception-decisions" "$TEST_ROOT/.context/working/.gate-bypass-log.yaml"
}

@test "T-1984: without CLAUDECODE, structural error is advisory only (exit 0)" {
    unset CLAUDECODE
    unset AI_AGENT
    local file="$TEST_ROOT/.tasks/active/T-9990-test.md"
    local content="---
id: T-9990
name: test
workflow_type: inception
inception_decisions:
  - id: bad
    text: 'bad'
    ships_in: justabareword
---
"
    run_hook_write "$file" "$content"
    [ "$status" -eq 0 ]
}

# ── unlocks_inception_decision — build task checks ────────────────────────────

@test "T-1984: valid unlocks_inception_decision reference passes" {
    # Create the inception task it references
    cat > "$TEST_ROOT/.tasks/completed/T-1983-inception.md" <<'EOF'
---
id: T-1983
name: inception
workflow_type: inception
inception_decisions:
  - id: my-decision
    text: 'The decision'
    ships_in: T-9990
---
# body
EOF
    local file="$TEST_ROOT/.tasks/active/T-9991-build.md"
    local content="---
id: T-9991
name: build
workflow_type: build
unlocks_inception_decision:
  - T-1983:my-decision
---
# body
"
    run_hook_write "$file" "$content"
    [ "$status" -eq 0 ]
}

@test "T-1984: build child with unlocks referencing non-existent decision blocks (AC-g)" {
    # Inception exists but doesn't have the decision
    cat > "$TEST_ROOT/.tasks/completed/T-1983-inception.md" <<'EOF'
---
id: T-1983
name: inception
workflow_type: inception
inception_decisions:
  - id: known-decision
    text: 'Known'
    ships_in: T-9990
---
# body
EOF
    local file="$TEST_ROOT/.tasks/active/T-9991-build.md"
    local content="---
id: T-9991
name: build
workflow_type: build
unlocks_inception_decision:
  - T-1983:ghost-decision
---
# body
"
    run_hook_write "$file" "$content"
    [ "$status" -eq 2 ]
    [[ "$output" == *"ghost-decision"* ]]
}

@test "T-1984: build child with malformed unlocks format blocks" {
    local file="$TEST_ROOT/.tasks/active/T-9991-build.md"
    local content="---
id: T-9991
name: build
workflow_type: build
unlocks_inception_decision:
  - just-bad-format
---
# body
"
    run_hook_write "$file" "$content"
    [ "$status" -eq 2 ]
    [[ "$output" == *"UNLOCKS_INCEPTION_DECISION ERROR"* ]]
}

@test "T-1984: build child unlocks referencing non-existent inception blocks" {
    # Inception does not exist at all
    local file="$TEST_ROOT/.tasks/active/T-9991-build.md"
    local content="---
id: T-9991
name: build
workflow_type: build
unlocks_inception_decision:
  - T-9999:my-decision
---
# body
"
    run_hook_write "$file" "$content"
    [ "$status" -eq 2 ]
    [[ "$output" == *"T-9999"* ]]
}

# ── path scoping ──────────────────────────────────────────────────────────────

@test "T-1984: hook ignores non-task files" {
    local content="---
inception_decisions:
  - id: bad
    text: bad
    ships_in: justabareword
---
"
    run_hook_write "$TEST_ROOT/.context/working/something.md" "$content"
    [ "$status" -eq 0 ]
}

@test "T-1984: hook ignores files outside .tasks/{active,completed}/" {
    local content="---
inception_decisions:
  - id: bad
    text: bad
    ships_in: justabareword
---
"
    run_hook_write "$TEST_ROOT/docs/T-9990-other.md" "$content"
    [ "$status" -eq 0 ]
}

# ── tool name filtering ───────────────────────────────────────────────────────

@test "T-1984: Bash tool passes through" {
    local input='{"tool_name":"Bash","tool_input":{"command":"echo hi"}}'
    run bash "$HOOK_SH" <<< "$input"
    [ "$status" -eq 0 ]
}

# ── Edit tool ─────────────────────────────────────────────────────────────────

@test "T-1984: Edit introducing bad inception_decisions blocks" {
    cat > "$TEST_ROOT/.tasks/active/T-9990-test.md" <<'EOF'
---
id: T-9990
name: test
workflow_type: inception
status: started-work
---
# body
EOF
    local input
    input=$(python3 -c "
import json
print(json.dumps({
    'tool_name': 'Edit',
    'tool_input': {
        'file_path': '$TEST_ROOT/.tasks/active/T-9990-test.md',
        'old_string': 'status: started-work',
        'new_string': 'status: started-work\ninception_decisions:\n  - id: BadID\n    text: bad\n    ships_in: T-100',
        'replace_all': False
    }
}))
")
    run bash "$HOOK_SH" <<< "$input"
    [ "$status" -eq 2 ]
    [[ "$output" == *"kebab-case"* ]]
}

# ── sanity ────────────────────────────────────────────────────────────────────

@test "T-1984: hook .py parses cleanly" {
    run python3 -m py_compile "$HOOK_PY"
    [ "$status" -eq 0 ]
}
