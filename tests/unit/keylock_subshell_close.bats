#!/usr/bin/env bats
# T-1493: keylock_subshell_close_cmd emits FD-close commands so verification
# subshells don't leak lock FDs to long-lived daemons (e.g., .NET VBCSCompiler).
# Origin: 003-NTB-ATC-Plugin pickup envelope P-015 / T-146

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TMP_PROJECT=$(mktemp -d)
    mkdir -p "$TMP_PROJECT/.context/locks"
    export PROJECT_ROOT="$TMP_PROJECT"
    # shellcheck source=lib/keylock.sh
    source "$FRAMEWORK_ROOT/lib/keylock.sh"
}

teardown() {
    # Best-effort lock release (test may have left FDs open)
    keylock_release "T-test1" 2>/dev/null || true
    keylock_release "T-test2" 2>/dev/null || true
    rm -rf "$TMP_PROJECT"
}

@test "no locks held → empty close-cmd output" {
    out=$(keylock_subshell_close_cmd)
    [ -z "$out" ]
}

@test "one lock held → emits exec N>&- for that FD" {
    keylock_acquire "T-test1"
    out=$(keylock_subshell_close_cmd)
    [[ "$out" == *"exec ${_KEYLOCK_FDS[T-test1]}>&-"* ]]
    keylock_release "T-test1"
}

@test "two locks held → emits close cmd for both" {
    keylock_acquire "T-test1"
    keylock_acquire "T-test2"
    out=$(keylock_subshell_close_cmd)
    [[ "$out" == *"exec ${_KEYLOCK_FDS[T-test1]}>&-"* ]]
    [[ "$out" == *"exec ${_KEYLOCK_FDS[T-test2]}>&-"* ]]
    keylock_release "T-test1"
    keylock_release "T-test2"
}

@test "subshell with eval'd close-cmd does NOT inherit the lock FD" {
    keylock_acquire "T-test1"
    local fd="${_KEYLOCK_FDS[T-test1]}"
    local close_cmd
    close_cmd=$(keylock_subshell_close_cmd)

    # Inside the subshell, after eval'ing close_cmd, the FD must be closed.
    # Test: try to read from the FD — should fail. Bash's redirect-failure
    # error message ("Bad file descriptor") leaks to stderr regardless of
    # 2>/dev/null on the redirect itself, so use substring + negative match.
    run bash -c "eval \"$close_cmd\"; if : <&$fd 2>/dev/null; then echo FD-OPEN; else echo FD-CLOSED; fi"
    [ "$status" -eq 0 ]
    [[ "$output" == *"FD-CLOSED"* ]]
    [[ "$output" != *"FD-OPEN"* ]]

    # Parent still holds the lock — verify FD entry still tracked.
    [ -n "${_KEYLOCK_FDS[T-test1]}" ]

    keylock_release "T-test1"
}

@test "without close-cmd, subshell DOES inherit the FD (regression baseline)" {
    keylock_acquire "T-test1"
    local fd="${_KEYLOCK_FDS[T-test1]}"

    # Baseline confirming the bug exists without the fix: subshell sees the FD.
    run bash -c "if : <&$fd 2>/dev/null; then echo 'FD-OPEN'; else echo 'FD-CLOSED'; fi"
    [ "$status" -eq 0 ]
    [[ "$output" == "FD-OPEN" ]]

    keylock_release "T-test1"
}
