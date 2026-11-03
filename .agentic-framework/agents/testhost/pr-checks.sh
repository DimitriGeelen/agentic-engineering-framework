#!/usr/bin/env bash
# pr-checks.sh BASE-REF — the R-12 pull-request checks, one script for both places (R-14, T-5009).
#
# Called by the `pr-checks` job of .github/workflows/test.yml and by the isolated test host's
# guest (agents/testhost/guest-run.sh). Run from the root of the checkout under test.
#   phase lint:    bats tests/lint/ (structural invariants)
#   phase changed: the bats/pytest test files added or changed between BASE-REF...HEAD
# Every phase prints `== PHASE <name> start ==` and `== PHASE <name> end rc=N seconds=S ==`.
# Both phases always run; the exit code is non-zero when any phase failed (the verdict is the
# same as the workflow's two steps had: pass only if both pass).
set -euo pipefail

base="${1:-}"
if [ -z "$base" ]; then
    echo "usage: pr-checks.sh BASE-REF" >&2
    exit 2
fi

overall=0

phase_lint() {
    bats tests/lint/
}

phase_changed() {
    local changed bats_files py_files rc=0
    changed=$(git diff --name-only --diff-filter=AM "$base"...HEAD -- tests/ || true)
    bats_files=$(printf '%s\n' "$changed" | grep -E '^tests/(unit|integration)/.*\.bats$' || true)
    py_files=$(printf '%s\n' "$changed" | grep -E '^tests/unit/(test_.*|.*_test)\.py$' || true)
    if [ -z "$bats_files$py_files" ]; then
        echo "No test files added or changed."
        return 0
    fi
    if [ -n "$bats_files" ]; then echo "$bats_files" | xargs bats || rc=1; fi
    if [ -n "$py_files" ]; then echo "$py_files" | xargs python3 -m pytest -q || rc=1; fi
    return $rc
}

run_phase() {
    local name="$1" fn="$2" t0 rc=0
    echo "== PHASE $name start =="
    t0=$(date +%s)
    "$fn" || rc=$?
    echo "== PHASE $name end rc=$rc seconds=$(( $(date +%s) - t0 )) =="
    if [ "$rc" -ne 0 ]; then overall=1; fi
}

run_phase lint phase_lint
run_phase changed phase_changed
exit "$overall"
