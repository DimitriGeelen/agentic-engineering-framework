#!/usr/bin/env bats
# T-4641 — `fw termlink check` must report a termlink that is on PATH but does not run.
#
# Before: cmd_check ran `version=$(termlink --version | head -1)` under set -euo
# pipefail, so a binary whose --version exits non-zero killed the script on that
# assignment: exit 97, no output at all (the integration red in fw_termlink.bats,
# where the T-4205 tripwire fake is the termlink on PATH).
# After: a WARN naming the path and the failed --version, exit 1. The control leg
# proves a working binary still reports OK.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.context/working" "$TEST_TEMP_DIR/stub"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_stub() {
    printf '#!/usr/bin/env bash\n%s\n' "$1" > "$TEST_TEMP_DIR/stub/termlink"
    chmod +x "$TEST_TEMP_DIR/stub/termlink"
}

@test "termlink on PATH whose --version fails: WARN with the path, exit 1, not a silent abort" {
    _stub 'exit 97'
    run env PATH="$TEST_TEMP_DIR/stub:$PATH" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" PROJECT_ROOT="$PROJECT_ROOT" \
        "$FRAMEWORK_ROOT/bin/fw" termlink check
    [ "$status" -eq 1 ]
    [[ "$output" == *"WARN"*"TermLink found at $TEST_TEMP_DIR/stub/termlink"*"--version' failed"* ]]
}

@test "control: a working termlink still reports OK with its version" {
    _stub '[ "${1:-}" = --version ] && echo "termlink 9.9.9-stub"; exit 0'
    run env PATH="$TEST_TEMP_DIR/stub:$PATH" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" PROJECT_ROOT="$PROJECT_ROOT" \
        "$FRAMEWORK_ROOT/bin/fw" termlink check
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"*"TermLink installed: termlink 9.9.9-stub"* ]]
}
