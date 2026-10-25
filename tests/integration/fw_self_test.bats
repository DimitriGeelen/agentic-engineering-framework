#!/usr/bin/env bats
# Integration tests for fw self-test
# Origin: T-947
#
# T-4644: `fw self-test` runs every phase (~150 s). Each test used to run it
# again, which took the file past the 900 s per-file integration cap under -j4.
# Every assertion reads the same output, so the file runs it once and shares it.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
FW="$FRAMEWORK_ROOT/bin/fw"

setup_file() {
    local rc=0
    "$FW" self-test > "$BATS_FILE_TMPDIR/self-test.out" 2>&1 || rc=$?
    echo "$rc" > "$BATS_FILE_TMPDIR/self-test.status"
}

setup() {
    status=$(cat "$BATS_FILE_TMPDIR/self-test.status")
    output=$(cat "$BATS_FILE_TMPDIR/self-test.out")
}

@test "fw self-test runs gate tests" {
    [ "$status" -le 1 ]  # May have failures but should complete
    [[ "$output" == *"gate"* ]] || [[ "$output" == *"self-test"* ]]
}

@test "fw self-test runs lifecycle tests" {
    [[ "$output" == *"lifecycle"* ]]
}

@test "fw self-test runs onboarding tests" {
    [[ "$output" == *"onboarding"* ]]
}

@test "fw self-test shows pass/fail results" {
    [[ "$output" == *"PASS"* ]] || [[ "$output" == *"pass"* ]]
}
