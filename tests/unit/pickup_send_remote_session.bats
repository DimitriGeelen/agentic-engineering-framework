#!/usr/bin/env bats
# T-1494: fw pickup send --remote requires --session
# Origin: 003-NTB-ATC-Plugin pickup envelope P-006

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TMP_PROJECT=$(mktemp -d)
    mkdir -p "$TMP_PROJECT/.context/pickup/inbox"
    export PROJECT_ROOT="$TMP_PROJECT"
    # shellcheck source=lib/pickup.sh
    source "$FRAMEWORK_ROOT/lib/pickup.sh"
}

teardown() {
    rm -rf "$TMP_PROJECT"
}

@test "--remote without --session errors with clear message" {
    run do_pickup_send --type bug-report --summary "test" --remote some-hub
    [ "$status" -eq 1 ]
    [[ "$output" == *"--remote requires --session"* ]]
}

@test "--remote with --session does not error on the gate" {
    # Stub termlink so we don't actually push. Capture the args it was called with.
    termlink() {
        echo "STUB termlink $*"
        return 0
    }
    export -f termlink
    run do_pickup_send --type bug-report --summary "test" --remote some-hub --session tl-target
    [ "$status" -eq 0 ]
    [[ "$output" == *"STUB termlink remote push some-hub tl-target"* ]]
}

@test "--session alone (no --remote) is accepted and ignored" {
    run do_pickup_send --type bug-report --summary "test" --session tl-target
    [ "$status" -eq 0 ]
    [[ "$output" == *"Created"* ]]
}

@test "help text mentions --session and the requirement" {
    run do_pickup_send --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--session"* ]]
    [[ "$output" == *"required with --remote"* ]]
}
