#!/usr/bin/env bats
# T-4205 — regression for the TermLink tripwire (G-115). The learning-post test
# (add_learning_id_allocator.bats) reached the real `termlink channel post` through
# the host binary; the shared helper puts a refusing fake first on PATH and
# tripwire_assert fails a test that made a non-probe call.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    # No tripwire_assert here: this file asserts the tripwire itself.
}

@test "t4205: termlink resolves to the tripwire, not a host binary" {
    [ "$(command -v termlink)" = "$FRAMEWORK_ROOT/tests/lib/termlink-tripwire/termlink" ]
}

@test "t4205: the old learning-post call is refused, recorded, and fails tripwire_assert" {
    run termlink channel post channel:learnings --msg-type learning-P-001 --payload "test learning"
    [ "$status" -eq 97 ]
    grep -q '^call channel post channel:learnings' "${BATS_TEST_TMPDIR}/termlink-tripwire.log"
    run tripwire_assert
    [ "$status" -ne 0 ]
    [[ "$output" == *"channel post channel:learnings"* ]]
}

@test "t4205: read-only probes are recorded as probes and pass tripwire_assert" {
    run termlink hub fingerprint
    run termlink discover --json
    run termlink channel post --help
    run tripwire_assert
    [ "$status" -eq 0 ]
}
