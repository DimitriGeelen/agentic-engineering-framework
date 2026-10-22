#!/usr/bin/env bats
# T-4624 (G-123): review links must be literal full URLs — two enforcement points
# beyond `fw task review` (covered by review_link_blocking_gate.bats):
#   1. PreToolUse hook check-review-links on Write/Edit of .tasks/active/T-*.md
#   2. update-task.sh check_review_links_for_partial, before the partial-complete flip

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    HOOK_SH="$FRAMEWORK_ROOT/agents/context/check-review-links.sh"
    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.tasks/active" "$TEST_ROOT/.context/working"
    echo "http://192.168.10.107:3000" > "$TEST_ROOT/.context/working/watchtower.url"
    export PROJECT_ROOT="$TEST_ROOT"
    unset FW_ALLOW_REVIEW_LINK_HOMEWORK
    TASK="$TEST_ROOT/.tasks/active/T-9999-test.md"
}

teardown() {
    rm -rf "$TEST_ROOT" 2>/dev/null
}

_task() {
    cat <<EOF
---
id: T-9999
workflow_type: build
---
## Acceptance Criteria
### Agent
- [x] done
### Human
- [ ] [REVIEW] check it
  **Steps:**
  1. $1
  **Expected:** fine
  **If not:** say so

## Verification
curl -sf "\$(bin/fw watchtower url)/designer" >/dev/null
EOF
}

_hook_write() {
    local input
    input=$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "Write", "tool_input": {"file_path": sys.argv[1], "content": sys.argv[2]}}))
' "$1" "$2")
    run bash "$HOOK_SH" <<< "$input"
}

_hook_edit() {
    local input
    input=$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "Edit", "tool_input": {"file_path": sys.argv[1], "old_string": sys.argv[2], "new_string": sys.argv[3]}}))
' "$1" "$2" "$3")
    run bash "$HOOK_SH" <<< "$input"
}

# --- hook --------------------------------------------------------------------

@test "hook blocks a Write introducing the T-4607 shell form" {
    _hook_write "$TASK" "$(_task 'Open `$(cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url)/designer` in a browser')"
    [ "$status" -eq 2 ]
    [[ "$output" == *"shell expression where a URL belongs"* ]]
    [[ "$output" == *"http://192.168.10.107:3000/review/T-9999"* ]]
}

@test "hook blocks a Write introducing a bare backticked route" {
    _hook_write "$TASK" "$(_task 'Open `/designer` in a browser')"
    [ "$status" -eq 2 ]
    [[ "$output" == *"bare route path"* ]]
}

@test "hook allows a literal full URL (Verification keeps its \$(...) form)" {
    _hook_write "$TASK" "$(_task 'Open http://192.168.10.107:3000/designer in a browser')"
    [ "$status" -eq 0 ]
}

@test "hook allows an unrelated Edit on a task that already carries a bad link" {
    _task 'Open `/designer` in a browser' > "$TASK"
    _hook_edit "$TASK" "- [x] done" "- [x] done (ticked again)"
    [ "$status" -eq 0 ]
}

@test "hook blocks an Edit that introduces a bad link" {
    _task 'Open http://192.168.10.107:3000/designer' > "$TASK"
    _hook_edit "$TASK" "Open http://192.168.10.107:3000/designer" 'Open $(bin/fw watchtower url)/designer'
    [ "$status" -eq 2 ]
}

@test "hook ignores files outside .tasks/active" {
    _hook_write "$TEST_ROOT/docs/x.md" "$(_task 'Open `/designer`')"
    [ "$status" -eq 0 ]
}

@test "hook bypass FW_ALLOW_REVIEW_LINK_HOMEWORK=1 allows and logs Tier-2" {
    export FW_ALLOW_REVIEW_LINK_HOMEWORK=1
    _hook_write "$TASK" "$(_task 'Open `/designer`')"
    [ "$status" -eq 0 ]
    grep -q "review-link-homework" "$TEST_ROOT/.context/working/.gate-bypass-log.yaml"
}

# --- partial-complete gate ---------------------------------------------------

_load_gate() {
    RED="" NC=""
    eval "$(awk '/^check_review_links_for_partial\(\) \{/,/^\}/' "$FRAMEWORK_ROOT/agents/task-create/update-task.sh")"
    TASK_FILE="$TASK"
}

@test "update-task.sh calls the review-link gate in the close sequence" {
    grep -qE '^[[:space:]]+check_review_links_for_partial$' "$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
}

@test "partial-complete gate refuses the T-4607 shell form" {
    _load_gate
    _task 'Open `$(cd /opt/x && bin/fw watchtower url)/designer`' > "$TASK"
    PARTIAL_COMPLETE=true
    run check_review_links_for_partial
    [ "$status" -eq 1 ]
    [[ "$output" == *"Cannot reach partial-complete"* ]]
}

@test "partial-complete gate passes a literal URL" {
    _load_gate
    _task 'Open http://192.168.10.107:3000/designer' > "$TASK"
    PARTIAL_COMPLETE=true
    run check_review_links_for_partial
    [ "$status" -eq 0 ]
}

@test "partial-complete gate is silent on a full completion" {
    _load_gate
    _task 'Open `/designer`' > "$TASK"
    PARTIAL_COMPLETE=false
    run check_review_links_for_partial
    [ "$status" -eq 0 ]
}
