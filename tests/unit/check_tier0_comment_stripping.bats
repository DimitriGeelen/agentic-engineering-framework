#!/usr/bin/env bats
# T-1427: check-tier0.sh must strip bash comments before pattern matching so
# that references to Tier 0 phrases inside `# ...` comments don't trigger
# false-positive blocks on benign diagnostic commands.
#
# check-tier0.sh reads tool input from stdin as JSON: {"tool_input": {"command": "..."}}
# and exits 2 to block, 0 to allow.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    # T-1428: redirect PROJECT_ROOT so the hook writes pending-*.yaml into the
    # sandbox instead of the real .context/approvals/ directory. Without this,
    # every "blocked" test case leaks a phantom pending Tier 0 approval.
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    mkdir -p "$TEST_TEMP_DIR/.context/approvals" "$TEST_TEMP_DIR/.context/working"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-tier0.sh"
}

# Helper: feed a command through the hook and capture exit code
_run_hook() {
    local cmd="$1"
    # Build JSON envelope. Use python to ensure correct escaping.
    local json
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_input':{'command': sys.argv[1]}}))" "$cmd")
    echo "$json" | bash "$HOOK"
}

@test "tier0 hook: bare 'fw inception decide' is blocked" {
    run _run_hook "fw inception decide T-123 go --rationale x"
    [ "$status" -eq 2 ]
}

@test "tier0 hook: 'fw inception decide' inside a # comment is allowed (T-1427)" {
    # Multi-line command with a comment mentioning the phrase.
    local cmd='stat -c "%y" /tmp/x
# who ran fw inception decide today
grep -q pattern /tmp/x'
    run _run_hook "$cmd"
    [ "$status" -eq 0 ]
}

@test "tier0 hook: trailing comment does NOT hide real danger (T-1427 guard)" {
    # Real command, then a comment. Must still block.
    local cmd='fw inception decide T-999 go   # note: legit call'
    run _run_hook "$cmd"
    [ "$status" -eq 2 ]
}

@test "tier0 hook: phrase inside a single-quoted string is allowed" {
    # Already covered by strip_quotes, but this documents the layering.
    run _run_hook "echo 'fw inception decide'"
    [ "$status" -eq 0 ]
}

@test "tier0 hook: phrase inside a double-quoted string is allowed" {
    run _run_hook 'echo "fw inception decide"'
    [ "$status" -eq 0 ]
}

@test "tier0 hook: bare 'fw task update --force' is blocked" {
    run _run_hook "fw task update T-1 --status work-completed --force"
    [ "$status" -eq 2 ]
}

@test "tier0 hook: '--force' reference in a comment is allowed (T-1427)" {
    local cmd='git status
# do not pass --force to fw task update here
echo done'
    run _run_hook "$cmd"
    [ "$status" -eq 0 ]
}

@test "tier0 hook: URL fragment (#foo not preceded by whitespace) is NOT treated as a comment" {
    # Edge case: URL with fragment identifier. Since `#` is not at line start
    # or preceded by whitespace, it's not a comment per bash rules. No Tier 0
    # phrase here anyway, but ensures our strip_comments regex doesn't
    # accidentally eat intra-token text.
    run _run_hook "curl https://example.com/path#fragment"
    [ "$status" -eq 0 ]
}
