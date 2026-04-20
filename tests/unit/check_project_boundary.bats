#!/usr/bin/env bats
# T-1361 / G-053-C: check-project-boundary must not scan quoted string content.
#
# The Bash-gate regex patterns used to apply to the raw command, including
# content INSIDE quoted arguments — so `git commit -m "mentions /root/foo"`
# got false-positived. Fix: strip balanced "..." and '...' content first.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    HOOK="$FRAMEWORK_ROOT/agents/context/check-project-boundary.sh"
    [ -x "$HOOK" ]
    export PROJECT_ROOT="$FRAMEWORK_ROOT"
}

# Helper: feed a JSON payload to the hook and capture exit code
run_hook() {
    local command="$1"
    # Build JSON with python to handle escaping cleanly
    local payload
    payload=$(python3 -c "
import json, sys
print(json.dumps({'tool_name': 'Bash', 'tool_input': {'command': sys.argv[1]}}))
" "$command")
    echo "$payload" | bash "$HOOK"
}

@test "boundary hook: FP fix — commit message with /root path is allowed" {
    run run_hook 'git commit -m "mentions /root/.agentic-framework/bin/fw in body"'
    [ "$status" -eq 0 ]
}

@test "boundary hook: FP fix — echo with quoted cd is allowed" {
    run run_hook "echo 'cd /opt/other && something' > note.txt"
    [ "$status" -eq 0 ]
}

@test "boundary hook: FP fix — heredoc-like quoted absolute path is allowed" {
    run run_hook 'cat > /tmp/msg.txt <<EOF
This mentions /opt/other/stuff
EOF'
    # Note: we don't actually strip heredocs, but /tmp/ write is whitelisted
    # and the /opt mention is inside the heredoc body which falls outside our
    # strip pass. This test documents behavior rather than asserts perfection.
    # Exit is 0 because the write target /tmp/msg.txt is whitelisted.
    [ "$status" -eq 0 ]
}

@test "boundary hook: TP preserved — actual unquoted cd to other project still blocked" {
    run run_hook "cd /opt/other-project && ls"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "PROJECT BOUNDARY BLOCK"
}

@test "boundary hook: TP preserved — unquoted direct fw invocation on other project still blocked" {
    run run_hook "/opt/other/.agentic-framework/bin/fw version"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "PROJECT BOUNDARY BLOCK"
}

@test "boundary hook: safe zone — cd to /tmp is allowed" {
    run run_hook "cd /tmp && ls"
    [ "$status" -eq 0 ]
}

@test "boundary hook: safe zone — cd within PROJECT_ROOT is allowed" {
    run run_hook "cd $PROJECT_ROOT/agents && ls"
    [ "$status" -eq 0 ]
}
