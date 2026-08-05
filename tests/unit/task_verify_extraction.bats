#!/usr/bin/env bats
# Unit tests for `fw task verify T-XXX` — verification block extraction.
#
# Origin: T-1541 (pickup from 003-NTB-ATC-Plugin/T-214). The previous BRE
# pattern `^\`\`\`` in the 4-grep pipeline was interpreted by GNU grep 3.11
# as `^` plus three start-of-buffer assertions — every line matched, `grep
# -v` stripped everything, the empty-result exit 1 propagated under
# `set -euo pipefail`, and the script aborted before reaching its
# diagnostic branch. The fix collapses to a single ERE with `|| true`,
# mirroring `update-task.sh:197`.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.context/working"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Write a task file with the given Verification block body.
_write_task() {
    local task_id="$1" body="$2"
    cat > "$PROJECT_ROOT/.tasks/active/${task_id}-test.md" <<EOF
---
id: ${task_id}
name: "Test task"
status: started-work
workflow_type: build
owner: agent
horizon: now
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
---

# ${task_id}: Test

## Verification

${body}

## Decisions

(none)
EOF
}

@test "fw task verify with populated block exits 0 and prints PASS" {
    _write_task "T-9001" $'true\necho ok >/dev/null\ntest -d /tmp'
    run "$FRAMEWORK_ROOT/bin/fw" task verify T-9001
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
    [[ "$output" == *"3/3 passed"* ]]
}

@test "fw task verify with empty block prints 'No verification commands found' and exits 0" {
    _write_task "T-9002" $'# only a comment\n# and another'
    run "$FRAMEWORK_ROOT/bin/fw" task verify T-9002
    [ "$status" -eq 0 ]
    [[ "$output" == *"No verification commands"* ]]
}

@test "fw task verify with a failing command exits 1 and prints FAIL" {
    _write_task "T-9003" $'true\nfalse\ntrue'
    run "$FRAMEWORK_ROOT/bin/fw" task verify T-9003
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
    [[ "$output" == *"2/3 passed"* ]]
}

@test "fw task verify ignores fenced code blocks (the L-294 / T-1541 trap)" {
    _write_task "T-9004" $'```bash\ntrue\n```\necho real-cmd >/dev/null'
    run "$FRAMEWORK_ROOT/bin/fw" task verify T-9004
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
    [[ "$output" != *"FAIL"* ]]
}

@test "the underlying grep pattern is robust to BRE/ERE differences" {
    # The fix uses `grep -vE '^##|^\s*```|^\s*#|^\s*$'` — ERE has no special
    # meaning for backtick. This asserts the pattern works in isolation.
    run bash -c "printf 'foo\n\`\`\`\nbar\n\`\`\`\nbaz\n' | grep -vE '^##|^\s*\`\`\`|^\s*#|^\s*\$' || true"
    [ "$status" -eq 0 ]
    [[ "$output" == *"foo"* ]]
    [[ "$output" == *"bar"* ]]
    [[ "$output" == *"baz"* ]]
    [[ "$output" != *"\`\`\`"* ]]
}
