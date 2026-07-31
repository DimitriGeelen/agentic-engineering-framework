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

# T-2701: the file predicate must match what a RUNNER WOULD COLLECT, and nothing
# else. bats runs *.bats; pytest collects test_*.py and *_test.py. Anything under
# tests/ that no runner would collect is not an orphaned test — it is a helper,
# and flagging it is a false positive. `tests/scripts/yaml_parse_all_tasks.py` is
# the live example: a verification helper called from task `## Verification`
# blocks, deliberately not collected, correctly not flagged. Per L-527, a guard
# with false positives is not a weaker guard, it is one that gets ignored.
#
# The original cut of this guard globbed *.bats ONLY, which is why it passed
# tests/web/ (32 pytest files, referenced by no runner — `fw test web` runs
# web/test_app.py, a different directory). Same shape as the trailing-comment
# miss in the same batch: the instance in front of me got fixed, not the class.
# 832 found the identical class their side (rail 348, their T-316) by running
# this guard's check against a tree it was never written for.
_collectable() {
    ls "$1"*.bats "$1"test_*.py "$1"*_test.py 2>/dev/null | head -1
}

@test "every tests/<dir>/ with collectable test files is referenced by bin/fw" {
    local orphans=()
    for d in "$TESTS_ROOT"/*/; do
        local name; name=$(basename "$d")
        [ -n "$(_collectable "$d")" ] || continue
        # Comments stripped: a comment mentioning the path is not a wiring
        # (L-519 — this guard would otherwise pass on the note explaining an
        # orphan, which is exactly the reassurance that let the original hide).
        if ! grep -vE '^\s*#' "$FW" | grep -q "tests/$name/"; then
            orphans+=("$name")
        fi
    done
    [ "${#orphans[@]}" -eq 0 ] || {
        echo "Test directories holding collectable tests that no runner globs:"
        printf '  tests/%s/\n' "${orphans[@]}"
        echo ""
        echo "Add a branch under \`fw test\` (see the 'invariants' branch, T-2697)."
        false
    }
}

@test "the standalone web branch and the all-suite name the same pytest targets" {
    # The dir-level guard above proves a directory is REACHABLE from bin/fw. It
    # does not prove every runner path reaches it: one mention anywhere turns it
    # green. T-2701 hit exactly that — `fw test web` and stage 3 of `fw test all`
    # each named the pytest target explicitly, so wiring tests/web/ into the first
    # left the second, the suite that actually gates, still blind.
    #
    # Comments stripped before matching: a comment naming a path is prose about
    # the wiring, not the wiring (L-519 — which has now caught this codebase's
    # guards three times, twice in trailing position).
    # The invariant, stated narrowly enough to mean something: any pytest call
    # that runs the web APP test file must also run the web TEST DIRECTORY.
    # (A first cut compared every pytest target list in the file and swept in the
    # playwright branch — over-matching, caught by running it rather than reading.)
    local app_calls dir_calls
    app_calls=$(sed 's/#.*//' "$FW" | grep -c 'python3 -m pytest.*web/test_app\.py' || true)
    dir_calls=$(sed 's/#.*//' "$FW" | grep -c 'python3 -m pytest.*web/test_app\.py.*tests/web/' || true)
    [ "$app_calls" -gt 0 ]  # the app test file is still wired at all
    [ "$app_calls" -eq "$dir_calls" ] || {
        echo "pytest runs web/test_app.py at $app_calls site(s) but tests/web/ at only $dir_calls."
        echo "A runner path names the app file without the test directory — tests/web/ is"
        echo "invisible in that path (T-2701)."
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
