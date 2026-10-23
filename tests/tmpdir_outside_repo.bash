# tests/tmpdir_outside_repo.bash — refuse a bats run whose temp root is inside the repo (T-4696)
#
# Sourced by tests/{unit,lint,integration,governance}/setup_suite.bash, which
# bats runs once per invocation before any test (bats picks the setup_suite.bash
# next to the first file argument).
#
# WHY. On 2026-10-22 a worker ran
#     TMPDIR=$PWD/.context/working/t4662tmp bats -j 6 <files>
# so every BATS_TEST_TMPDIR, and every fixture project built in one, sat INSIDE
# the framework checkout. Test 598 of that run wrote a handover into
# .../bats-run-aOWVHW/test/598/proj/.context/handovers/, and the next real
# handover commit (0b514d2c4) picked both files up. Fixtures under the repo are
# visible to the repo's `git status`/`git add -A`, and a fixture that is not
# itself a git repo resolves git commands to the real one. tests/git_fence.bash
# and tests/live_repo_guard.bash both assume the temp root is OUTSIDE the
# checkout; nothing asserted it. The T-3234 lint's own comment recommended an
# in-repo TMPDIR as the way to see it fail.
#
# WHAT. Resolve the run's temp root (BATS_RUN_TMPDIR, falling back to TMPDIR)
# and the repo root physically, and fail when the first is the repo or under it.

# tmpdir_inside_repo REPO DIR — exit 0 when DIR is REPO or a descendant of it
tmpdir_inside_repo() {
    local repo dir
    repo="$(cd "$1" 2>/dev/null && pwd -P)" || return 1
    dir="$(realpath -m "$2" 2>/dev/null)" || return 1
    [ -n "$dir" ] || return 1
    case "$dir/" in "$repo/"*) return 0 ;; esac
    return 1
}

# refuse_tmpdir_inside_repo REPO — return 1 (message on stderr) if this bats
# run's temp root lies inside REPO
refuse_tmpdir_inside_repo() {
    local repo d
    repo="$(cd "$1" 2>/dev/null && pwd -P)" || repo="$1"
    for d in "${BATS_RUN_TMPDIR:-}" "${TMPDIR:-}"; do
        [ -n "$d" ] || continue
        if tmpdir_inside_repo "$repo" "$d"; then
            {
                echo "TMPDIR INSIDE THE REPO (T-4696): bats temp root $d"
                echo "is inside $repo. Test fixtures written there show up in the"
                echo "real repo's git status and can be committed by the next"
                echo "handover. Use a temp dir outside the checkout, e.g."
                echo "    TMPDIR=\$(mktemp -d) bats ..."
            } >&2
            return 1
        fi
    done
    return 0
}
