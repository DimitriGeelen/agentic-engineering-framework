#!/usr/bin/env bats
# T-4644: tests/integration/fw_self_test.bats ran the full `fw self-test`
# (~150 s, every phase) once per test — 4x — and blew the 900 s per-file
# integration cap under -j4. All its assertions read the same output, so the
# file must run it once (setup_file) and share the capture.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
TARGET="$FRAMEWORK_ROOT/tests/integration/fw_self_test.bats"

@test "fw_self_test.bats invokes fw self-test exactly once" {
    n=$(grep -c '"$FW" self-test' "$TARGET")
    [ "$n" -eq 1 ]
}

@test "the single self-test run happens in setup_file, not per test" {
    run awk '/^setup_file\(\)/{f=1} f&&/"\$FW" self-test/{print "in-setup-file"; exit} /^}/{f=0}' "$TARGET"
    [ "$output" = "in-setup-file" ]
}

@test "fw_self_test.bats keeps all four assertions" {
    n=$(grep -c '^@test ' "$TARGET")
    [ "$n" -eq 4 ]
}
