#!/usr/bin/env bats
# T-3324 / OBS-368 — doctor check 9 ("Test infrastructure") must be cheap.
#
# The check used to shell out to `bats --count tests/unit/` (~79s over 600+
# files, measured 2026-09-07) to print a cosmetic test total, and --quick did
# not skip it — doctor sits on hook/cron/pre-push paths, so the cost was paid
# constantly and made doctor unusable inside test suites (a `fw doctor --quick`
# exceeded a 120s timeout having reached only check 8 during T-3281).
#
# Pins are source-level on purpose (F7/T-2451 lesson: running full doctor in
# unit tests is the anti-pattern this task removes). The behavioural --quick
# path is already exercised by t2452_doctor_quick.bats.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    FW_BIN="$FRAMEWORK_ROOT/bin/fw"
    [ -x "$FW_BIN" ]
}

@test "T-3324: bin/fw never invokes 'bats --count' (full mode is a file count)" {
    # Comment lines may mention the removed invocation (the T-3324 note does);
    # only a non-comment occurrence is a regression.
    ! grep -E '^[^#]*bats --count' "$FW_BIN"
}

@test "T-3324: check 9 (Test infrastructure) is guarded by _doctor_quick_skip" {
    grep -q '_doctor_quick_skip "Test infrastructure' "$FW_BIN"
}

@test "T-3324: the OK line words the count as FILES, not tests" {
    # The number printed is `ls tests/unit/*.bats | wc -l` — a file count. The
    # wording must not claim a test count it no longer measures.
    grep -q 'unit test files' "$FW_BIN"
    ! grep -qE '\$test_count unit tests\)' "$FW_BIN"
}
