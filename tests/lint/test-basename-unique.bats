#!/usr/bin/env bats
# T-4974 — pytest test files need unique basenames across the directories that are collected
# together. tests/ has no __init__.py packages, so pytest imports every test file as a
# top-level module; two files named test_x.py in two collected directories abort collection
# ("import file mismatch"), and EVERY test in that run goes unrun. Behind `| tail`, that looks
# like a short pass. Found 2026-11-01 when a 50-file run collected 0 tests.
#
# tests/unit, tests/web, tests/integration and tests/lint are run together (fw audit, ad-hoc
# reruns of "every test that reads X"). tests/playwright is run on its own (fw test
# playwright) and keeps many unit-named files on purpose, so it is out of scope here.

ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

@test "no pytest file basename is shared between tests/unit, tests/web, tests/integration, tests/lint" {
    run bash -c "cd '$ROOT' && find tests/unit tests/web tests/integration tests/lint \
        \\( -name 'test_*.py' -o -name '*_test.py' \\) -printf '%f\n' 2>/dev/null | sort | uniq -d"
    [ "$status" -eq 0 ]
    [ -z "$output" ] || { echo "shared basenames (rename one of each): $output"; return 1; }
}

@test "CONTROL: the check sees a planted duplicate" {
    tmp="$(mktemp -d)"
    mkdir -p "$tmp/tests/unit" "$tmp/tests/web" "$tmp/tests/integration" "$tmp/tests/lint"
    touch "$tmp/tests/unit/test_dup.py" "$tmp/tests/web/test_dup.py"
    run bash -c "cd '$tmp' && find tests/unit tests/web tests/integration tests/lint \
        \\( -name 'test_*.py' -o -name '*_test.py' \\) -printf '%f\n' | sort | uniq -d"
    rm -rf "$tmp"
    [ "$output" = "test_dup.py" ]
}
