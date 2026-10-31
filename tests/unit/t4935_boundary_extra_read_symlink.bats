#!/usr/bin/env bats
# T-4935 (GitHub #104 reply IC_kwDORdtOLc8AAAABhRyejw): a BOUNDARY_EXTRA_READ_PATHS
# entry that is a symbolic link was stored only in resolved form, while the command's
# path is compared as typed, so the link path the operator runs stayed blocked.
# The submitter's steps: a script under $HOME/tools, a link to it, the link listed.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    HOOK="$FRAMEWORK_ROOT/agents/context/check-project-boundary.sh"
    [ -x "$HOOK" ]
    export PROJECT_ROOT="$FRAMEWORK_ROOT"
    # A private dir outside every built-in read allowlist entry (/tmp is allowed,
    # /var/tmp is not), so the link path is refused unless the setting admits it.
    BASE="$(mktemp -d -p /var/tmp t4935.XXXXXX)"
    mkdir -p "$BASE/tools"
    printf '#!/bin/sh\necho ok\n' > "$BASE/tools/t.sh"
    chmod +x "$BASE/tools/t.sh"
    ln -s "$BASE/tools/t.sh" "$BASE/t"
    export HOME="/home/t4935user"
    export FW_BOUNDARY_EXTRA_READ_PATHS="$BASE/t"
}

teardown() {
    rm -f "$BASE/t" "$BASE/tools/t.sh"
    rmdir "$BASE/tools" "$BASE" 2>/dev/null || true
    rm -rf "$TEST_TEMP_DIR"
}

run_bash() {
    local payload
    payload=$(python3 -c "
import json, sys
print(json.dumps({'tool_name': 'Bash', 'tool_input': {'command': sys.argv[1]}}))
" "$1")
    echo "$payload" | bash "$HOOK"
}

@test "a listed symlink is readable by its link path" {
    run run_bash "$BASE/t --help"
    [ "$status" -eq 0 ]
}

@test "a listed symlink is readable by its target path" {
    run run_bash "$BASE/tools/t.sh --help"
    [ "$status" -eq 0 ]
}

@test "control: an unlisted sibling of the link stays blocked" {
    run run_bash "cat $BASE/other"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not in read-side allowlist"* ]]
}

@test "control: with nothing listed the link path blocks" {
    export FW_BOUNDARY_EXTRA_READ_PATHS=""
    run run_bash "$BASE/t --help"
    [ "$status" -ne 0 ]
}
