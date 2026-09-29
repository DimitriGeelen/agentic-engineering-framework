#!/usr/bin/env bash
# lib/push-resolve.sh — T-3550
#
# What actually happened to a push that `timeout` killed?
#
# WHY THIS EXISTS
# ---------------
# `timeout N git push` bounds the LOCAL PROCESS. It does not bound, and cannot
# roll back, the transaction on the remote. Those are different things, and the
# gap between them is real work:
#
#   remote receives the pack, updates the ref, starts reporting back
#   ...timeout fires...
#   local git is killed before it writes refs/remotes/ and before it exits 0
#
# The push SUCCEEDED. Exit 124 says only that we stopped waiting for the
# sentence to finish. Recording that as a failure tells the operator to retry
# something already done, and — worse — leaves the local remote-tracking ref
# behind the remote.
#
# THE TRAP THAT MAKES THIS WORTH A FILE
# -------------------------------------
# The obvious way to check agrees with the wrong answer. Because the kill is
# precisely what prevents `refs/remotes/<remote>/<branch>` from advancing,
#
#     git rev-list --count origin/<branch>..HEAD
#
# reports commits outstanding — so the predicate you would reach for to confirm
# the failure CONFIRMS IT, and is wrong for exactly the same reason the original
# report was wrong. One stale cache, two agreeing voices, no disagreement to
# notice. Measured on handover S-2026-0929-0932: remote at c97d39fb1, tracking
# ref at 28938d2de, `.push-state.json` reading `killed`, everything consistent
# and everything wrong.
#
# Only `git ls-remote` resolves it, because only `ls-remote` asks the remote.
#
# SO THIS FILE IS DELIBERATELY ONLINE
# -----------------------------------
# That is why it is not in lib/push-state.sh, whose `_fw_push_state_unpushed`
# documents an explicit offline contract (T-3025: handover generation must not
# hit the network). Both contracts are correct; they are not the same contract,
# and mixing them in one file is how one of them would quietly get broken.
# Call this one only where the network is already in play — right after a push.
#
# INDETERMINATE IS A REAL ANSWER
# ------------------------------
# If the remote cannot be reached, we do not know, and saying so is the whole
# job. Degrading silently to `not-landed` would rebuild the defect this file
# removes, one level down (OBS-566, L-665: a producer must be able to say
# "no verdict" in words distinct from "verdict: no").
#
# Interface:
#
#   fw_push_resolve_killed <root> <remote> [<timeout-seconds>]
#       stdout, exactly one line:
#         landed                    the remote carries HEAD; the push completed
#         not-landed                the remote answered and does NOT carry HEAD
#         indeterminate:<reason>    we could not find out (unreachable|no-branch)
#       rc: ALWAYS 0. A finding is not an error (OBS-566) — callers run under
#           `set -e` and a non-zero return here would kill them mid-report.
#
#       Side effect on `landed` ONLY: repairs refs/remotes/<remote>/<branch> to
#       HEAD — the write the kill prevented. Safe because it is applied only
#       after confirming the remote reports that exact sha.

# BOUNDARY: this resolves the BRANCH ref. `git push --follow-tags` may also
# carry tags, and a kill can land the branch while leaving a tag behind. A
# missing tag is picked up by the next push and does not strand commits, so it
# is out of scope here rather than silently covered — said plainly so the next
# reader does not infer coverage that is not there.
fw_push_resolve_killed() {
    local root="${1:-$PWD}" remote="${2:-origin}" tmo="${3:-60}"
    local branch head ls_out ls_rc remote_sha

    branch=$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    head=$(git -C "$root" rev-parse HEAD 2>/dev/null || echo "")

    # Detached HEAD has no branch ref to compare against on the remote. That is
    # not a failure to reach anything, so it gets its own reason rather than
    # being folded into `unreachable`.
    if [ -z "$branch" ] || [ "$branch" = "HEAD" ] || [ -z "$head" ]; then
        printf 'indeterminate:no-branch\n'
        return 0
    fi

    ls_out=$(timeout "$tmo" git -C "$root" ls-remote "$remote" "refs/heads/$branch" 2>/dev/null)
    ls_rc=$?

    # Non-zero: the remote did not answer (network, auth, or `timeout` killing
    # this too). We learned nothing, and must not pretend otherwise.
    if [ "$ls_rc" -ne 0 ]; then
        printf 'indeterminate:unreachable\n'
        return 0
    fi

    remote_sha=$(printf '%s\n' "$ls_out" | awk 'NR==1{print $1}')

    # ls-remote exits 0 with EMPTY output when the ref simply is not there. The
    # remote answered; the answer is "no such branch". That is knowledge, not
    # absence of it — a first push that was killed before creating the ref.
    if [ -z "$remote_sha" ]; then
        printf 'not-landed\n'
        return 0
    fi

    if [ "$remote_sha" = "$head" ]; then
        git -C "$root" update-ref "refs/remotes/$remote/$branch" "$head" 2>/dev/null || true
        printf 'landed\n'
    else
        printf 'not-landed\n'
    fi
    return 0
}
