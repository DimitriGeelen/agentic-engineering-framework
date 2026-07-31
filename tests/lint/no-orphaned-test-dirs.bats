#!/usr/bin/env bats
# T-2697 — every tests/<dir>/ holding .bats files must be reachable from a runner.
#
# Origin: tests/lint/ held 7 invariant test files and was globbed by NO runner
# from creation until 2026-07-31. Seven of its tests were red, one since
# 2026-06-10, and nothing said so. The verb that looks like it runs them —
# `fw test lint` — runs shellcheck, so its green output actively reassured.
#
# The failure class is the one this whole directory exists to catch: a guard
# that reports success by not running. Directory-level, so it applies to the
# next tests/<thing>/ someone adds as well as to the ones here today.

FW="$BATS_TEST_DIRNAME/../../bin/fw"
TESTS_ROOT="$BATS_TEST_DIRNAME/.."

@test "every tests/<dir>/ with .bats files is referenced by bin/fw" {
    local orphans=()
    for d in "$TESTS_ROOT"/*/; do
        local name; name=$(basename "$d")
        ls "$d"*.bats >/dev/null 2>&1 || continue
        # Comments stripped: a comment mentioning the path is not a wiring
        # (L-519 — this guard would otherwise pass on the note explaining an
        # orphan, which is exactly the reassurance that let the original hide).
        if ! grep -vE '^\s*#' "$FW" | grep -q "tests/$name/"; then
            orphans+=("$name")
        fi
    done
    [ "${#orphans[@]}" -eq 0 ] || {
        echo "Test directories with .bats files that no runner globs:"
        printf '  tests/%s/\n' "${orphans[@]}"
        echo ""
        echo "Add a branch under \`fw test\` (see the 'invariants' branch, T-2697)."
        false
    }
}

@test "the invariants branch actually reaches bats" {
    # Guards the wiring itself, not just its presence in the file: a branch that
    # exists but never reaches bats is the same silence with extra steps.
    #
    # An EXPLICIT target, deliberately. Invoking `fw test invariants` bare from
    # inside tests/lint/ re-runs this file, which re-invokes the runner, forever
    # — the first cut of this test hung until it was killed. A guard that runs
    # the suite containing it needs a fixed point, and naming one other file is
    # the cheapest one.
    run "$FW" test invariants "$BATS_TEST_DIRNAME/single-vendor-writer.bats"
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]  # 1 = a test failed, still ran
    echo "$output" | grep -q "Invariant Tests"
    # …and it reported per-test results, so it did more than print a header.
    echo "$output" | grep -qE '^(ok|not ok) '
}
