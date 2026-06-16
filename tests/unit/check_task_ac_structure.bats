#!/usr/bin/env bats
# T-2420: check-task-ac-structure PreToolUse hook — unit tests.
#
# Implements T-2418 GO. Hook prevents the structural error caught at the
# T-2417 close cascade (S-2026-0616): `### Human` placed AFTER an intervening
# `## ` heading is invisible to update-task.sh's AC parser.
#
# Covers:
#   - new malformed Write under CLAUDECODE → block (exit 2)
#   - new correctly-structured Write → allow (exit 0)
#   - no-Human file → allow (no heading to check)
#   - override env-var FW_ALLOW_AC_STRUCTURE_DRIFT=1 → allow + log
#   - non-task file path → pass-through
#   - Edit synth → block when malformation introduced
#   - MultiEdit synth → block when malformation introduced
#   - outside agent (no CLAUDECODE, no AI_AGENT) → advisory mode (exit 0 + NOTE)
#   - grandfather: edit a pre-existing offender without worsening → allow
#   - non-matching tool (e.g. Bash) → pass-through

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    HOOK_SH="$FRAMEWORK_ROOT/agents/context/check-task-ac-structure.sh"
    HOOK_PY="$FRAMEWORK_ROOT/agents/context/check-task-ac-structure.py"
    [ -f "$HOOK_SH" ] || skip "hook .sh wrapper not found"
    [ -f "$HOOK_PY" ] || skip "hook .py implementation not found"

    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.tasks/active" "$TEST_ROOT/.tasks/completed" "$TEST_ROOT/.context/working"

    export PROJECT_ROOT="$TEST_ROOT"
    export CLAUDECODE=1
    unset FW_ALLOW_AC_STRUCTURE_DRIFT
    unset AI_AGENT
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
    'file_path': sys.argv[1], 'old_string': sys.argv[2], 'new_string': sys.argv[3], 'replace_all': False}}))
" "$file" "$old_str" "$new_str")
    run bash "$HOOK_SH" <<< "$input"
}

run_hook_multiedit() {
    local file="$1"
    shift
    # remaining args alternating old new old new ...
    local edits_json
    edits_json=$(python3 -c "
import json, sys
args = sys.argv[1:]
edits = []
for i in range(0, len(args), 2):
    edits.append({'old_string': args[i], 'new_string': args[i+1], 'replace_all': False})
print(json.dumps({'tool_name': 'MultiEdit', 'tool_input': {'file_path': '$file', 'edits': edits}}))
" "$@")
    run bash "$HOOK_SH" <<< "$edits_json"
}

# Returns a string with malformed structure (### Human AFTER ## Build summary)
malformed_content() {
    cat <<'EOF'
---
id: T-9990
---
## Acceptance Criteria

### Agent
- [ ] foo

## Build summary
stuff

### Human
- [ ] [REVIEW] bar
EOF
}

correct_content() {
    cat <<'EOF'
---
id: T-9990
---
## Acceptance Criteria

### Agent
- [ ] foo

### Human
- [ ] [REVIEW] bar

## Build summary
stuff
EOF
}

# ── tests ─────────────────────────────────────────────────────────────────────

@test "t1: new malformed Write under CLAUDECODE blocks (exit 2)" {
    target="$TEST_ROOT/.tasks/active/T-9990.md"
    run_hook_write "$target" "$(malformed_content)"
    [ "$status" -eq 2 ]
    [[ "$output" == *"TASK AC STRUCTURE ERROR"* ]]
    [[ "$output" == *"T-9990"* ]]
}

@test "t2: new correctly-structured Write allows (exit 0)" {
    target="$TEST_ROOT/.tasks/active/T-9990.md"
    run_hook_write "$target" "$(correct_content)"
    [ "$status" -eq 0 ]
}

@test "t3: file with no ### Human heading passes through" {
    target="$TEST_ROOT/.tasks/active/T-9990.md"
    content=$'---\nid: T-9990\n---\n## Acceptance Criteria\n### Agent\n- [ ] foo\n## Other\n'
    run_hook_write "$target" "$content"
    [ "$status" -eq 0 ]
}

@test "t4: override FW_ALLOW_AC_STRUCTURE_DRIFT=1 allows and logs" {
    target="$TEST_ROOT/.tasks/active/T-9990.md"
    export FW_ALLOW_AC_STRUCTURE_DRIFT=1
    run_hook_write "$target" "$(malformed_content)"
    [ "$status" -eq 0 ]
    [[ "$output" == *"FW_ALLOW_AC_STRUCTURE_DRIFT=1"* ]]
    [ -f "$TEST_ROOT/.context/working/.gate-bypass-log.yaml" ]
    grep -q "T-9990" "$TEST_ROOT/.context/working/.gate-bypass-log.yaml"
    grep -q "FW_ALLOW_AC_STRUCTURE_DRIFT" "$TEST_ROOT/.context/working/.gate-bypass-log.yaml"
}

@test "t5: non-task file path passes through" {
    target="$TEST_ROOT/some-file.md"
    run_hook_write "$target" "$(malformed_content)"
    [ "$status" -eq 0 ]
}

@test "t6: Edit synth that introduces malformation blocks" {
    target="$TEST_ROOT/.tasks/active/T-9990.md"
    # Start with correct file on disk
    correct_content > "$target"
    # Edit to scramble order so Human ends up outside AC
    run_hook_edit "$target" "### Human
- [ ] [REVIEW] bar

## Build summary
stuff" "## Build summary
stuff

### Human
- [ ] [REVIEW] bar"
    [ "$status" -eq 2 ]
    [[ "$output" == *"TASK AC STRUCTURE ERROR"* ]]
}

@test "t7: MultiEdit synth that introduces malformation blocks" {
    target="$TEST_ROOT/.tasks/active/T-9990.md"
    correct_content > "$target"
    run_hook_multiedit "$target" \
        "### Human
- [ ] [REVIEW] bar" "REPLACED_HUMAN_HERE" \
        "## Build summary
stuff" "## Build summary
stuff

### Human
- [ ] [REVIEW] bar"
    [ "$status" -eq 2 ]
}

@test "t8: outside agent (no CLAUDECODE) is advisory (exit 0 + NOTE)" {
    target="$TEST_ROOT/.tasks/active/T-9990.md"
    unset CLAUDECODE
    unset AI_AGENT
    run_hook_write "$target" "$(malformed_content)"
    [ "$status" -eq 0 ]
    [[ "$output" == *"would block under agent control"* ]]
}

@test "t9: grandfather — edit pre-existing offender without worsening passes" {
    target="$TEST_ROOT/.tasks/completed/T-9990.md"
    # Start with malformed file on disk (pre-existing offender)
    malformed_content > "$target"
    # Edit a totally unrelated line — Human still outside AC, but count unchanged
    run_hook_edit "$target" "id: T-9990" "id: T-9990
name: edited"
    [ "$status" -eq 0 ]
}

@test "t10: non-matching tool (Bash) passes through" {
    input='{"tool_name":"Bash","tool_input":{"command":"echo hi"}}'
    run bash "$HOOK_SH" <<< "$input"
    [ "$status" -eq 0 ]
}
