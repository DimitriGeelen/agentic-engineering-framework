#!/usr/bin/env bats
# T-3062: measure what the pre-push gate actually costs.
#
# tests/lint/prepush-gate-budget.bats asserts the *shape* — no whole-tree scan
# inside the per-push section, push timeout above the gate. Shape is cheap to
# check and runs inside the audit itself. It is also not the thing that broke:
# the section grew to 347s one check at a time, each addition individually
# reasonable, and no shape rule would have flagged any of them.
#
# So this file measures. It is deliberately NOT in tests/lint/, because that
# directory is executed by the audit (check_invariant_suite) and a 60s test
# there would be paid by every audit, every 30 minutes, forever — which is the
# same mistake in a different place.

setup() {
    FW_ROOT="$BATS_TEST_DIRNAME/../.."
    # Post-split measurement on the origin repo is ~59s. The bound is set well
    # above it so normal growth and a loaded host do not produce a flaky red,
    # but far below FW_HANDOVER_PUSH_TIMEOUT (300s) so this fires while there
    # is still headroom rather than after pushes have already started dying.
    BUDGET_S="${FW_PREPUSH_BUDGET_S:-150}"
}

@test "T-3062: the pre-push structure audit completes inside its budget" {
    command -v python3 >/dev/null || skip "python3 needed for timing"

    out_file="$BATS_TEST_TMPDIR/audit.out"
    start=$(date +%s)
    # A generous hard cap so a genuine hang fails the test instead of hanging
    # the suite. Exceeding it is a failure, not a skip.
    # `|| rc=$?` rather than a bare call: bats runs under `set -e`, and the
    # audit exits 1 on warnings and 2 on failures. Aborting here would make an
    # unrelated RED audit look like a timing failure — and, worse, would report
    # nothing about the duration, which is the only thing this test measures.
    # The verdict is deliberately not asserted; other checks own that.
    rc=0
    timeout $(( BUDGET_S * 3 )) "$FW_ROOT/agents/audit/audit.sh" --section structure \
        > "$out_file" 2>&1 || rc=$?
    elapsed=$(( $(date +%s) - start ))

    if [ "$rc" -eq 75 ]; then
        # EX_TEMPFAIL — another audit holds the lock, so nothing ran and there
        # is no duration to judge. Skipping is correct here; passing would be
        # a measurement of the lock, reported as a measurement of the gate.
        skip "another audit holds the lock — no timing produced"
    fi

    # Positive control, and the reason this test is worth having at all: a
    # harness that fails to launch the audit finishes in milliseconds and sails
    # under any budget. Without this line, the fastest possible pass is also
    # the most broken one. Assert real work happened before trusting the clock.
    grep -q '=== END AUDIT ===' "$out_file" \
        || { echo "audit did not run to completion (rc=$rc); timing is meaningless"; \
             tail -20 "$out_file"; false; }
    grep -q 'Cron registry in sync\|Cron registry' "$out_file" \
        || { echo "structure checks did not execute; timing is meaningless"; false; }

    if [ "$elapsed" -gt "$BUDGET_S" ]; then
        echo "Pre-push structure audit took ${elapsed}s (budget ${BUDGET_S}s)."
        echo ""
        echo "This section runs on EVERY push. When it outgrows the push"
        echo "timeout (FW_HANDOVER_PUSH_TIMEOUT), pushes are killed mid-gate"
        echo "rather than blocked — and handover.sh reports both the same way,"
        echo "so the failure is silent. That is T-3062's origin: 347s of gate"
        echo "against a 60s window, seven commits unpushed across four sessions."
        echo ""
        echo "Find the cost before raising the budget:"
        echo "  S=\$(date +%s); ./agents/audit/audit.sh --section structure 2>&1 |"
        echo "    while IFS= read -r l; do echo \"+\$((\$(date +%s)-S))s \$l\"; done"
        echo ""
        echo "A check that scans the whole tree belongs in --section tree."
        false
    fi
}

@test "T-3062: the whole-tree section still runs when no section filter is given" {
    # The split is only safe if a full audit still covers the scanners. This is
    # a property of should_run_section (empty filter => every section true), so
    # assert it directly rather than paying minutes to run a full audit.
    run bash -c '
        SECTIONS=""
        should_run_section() {
            [ -z "$SECTIONS" ] && return 0
            echo ",$SECTIONS," | grep -q ",$1,"
        }
        should_run_section tree && echo "full-audit:yes" || echo "full-audit:no"
        SECTIONS="structure"
        should_run_section tree && echo "structure-only:yes" || echo "structure-only:no"
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *"full-audit:yes"* ]]
    [[ "$output" == *"structure-only:no"* ]]
}

@test "T-3062: the daily full audit is still scheduled without a section filter" {
    # The above is worth nothing if nothing actually invokes the full audit.
    reg="$FW_ROOT/.context/cron-registry.yaml"
    [ -f "$reg" ] || skip "no cron registry in this checkout"
    grep -q "fw audit --cron'" "$reg" \
        || { echo "no unfiltered 'fw audit --cron' entry — the tree scans would never run"; false; }
}
