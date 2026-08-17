#!/usr/bin/env bash
# lib/push-state.sh — T-3063 (leg 2 of T-3062)
#
# Push outcomes, remembered across sessions.
#
# WHY THIS EXISTS
# ---------------
# The framework already counts unpushed commits at handover time (T-3025,
# handover.sh). That counter fired correctly in four consecutive sessions and
# printed `⚠ 7 commit(s) NOT pushed` every time, and every time it was ignored
# — because the line reads *identically* at one commit five minutes old and at
# seven commits across four failed pushes. A count is a snapshot. "Stuck" is a
# property of history, and nothing was keeping any.
#
# So this file keeps a little: how many consecutive sessions the push has
# failed, when the streak started, and how the last one failed.
#
# THE DISTINCTION THAT MATTERS
# ----------------------------
# A push can fail in two categorically different ways and they need different
# words:
#
#   killed   the pre-push gate did not finish inside the timeout bounding it.
#            NO VERDICT WAS PRODUCED. The gate did not let you through and did
#            not refuse you; it never got to the end. (T-3062: a 347s audit
#            inside a 60s window, four sessions running.)
#
#   refused  a gate ran to completion and said no, or the remote rejected the
#            push. There IS a verdict, and it is actionable as written.
#
# T-2930/OBS-221 drew exactly this line for audit exit 75 — "contention is not
# a pass, because no verdict was produced" — inside the audit, and never at the
# caller that wraps it in `timeout`. This is that same reasoning, one level up.
#
# SELF-HEALING IS NOT OPTIONAL
# ----------------------------
# The state is a cache of an observable fact, and the fact wins. If a human
# pushes by hand, or from another checkout, the streak is over whether or not
# anything told us. `fw_push_state_read` therefore verifies against
# `rev-list <remote-ref>..HEAD` before reporting, and clears itself when they
# disagree. An escalation that keeps shouting after the problem is gone gets
# tuned out exactly like the signal it was built to replace.
#
# Interface (token-prefixed stdout, empty when there is nothing to say — same
# shape as lib/branch-hygiene.sh, so `fw doctor` consumes it the same way):
#
#   fw_push_state_record <root> <outcome> [<kind>] [<session-id>]
#       outcome: success | failure     kind: killed | refused | unknown
#
#   fw_push_state_read <root>
#       prints nothing when there is no active streak, else one line:
#         stuck-push branch=<b> failures=<n> unpushed=<u> since=<iso> kind=<k>
#
#   fw_push_state_clear <root>

FW_PUSH_STATE_REL=".context/working/.push-state.json"

_fw_push_state_file() {
    printf '%s/%s\n' "${1:-$PWD}" "$FW_PUSH_STATE_REL"
}

_fw_push_state_branch() {
    git -C "${1:-$PWD}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo ""
}

# Unpushed commit count against the local remote-tracking ref. No fetch: the
# ref is updated by our own pushes, which is exactly the question being asked,
# and handover generation must stay offline (T-3025).
_fw_push_state_unpushed() {
    local root="$1" branch="$2"
    git -C "$root" rev-parse --verify --quiet "refs/remotes/origin/$branch" >/dev/null 2>&1 || {
        echo "-1"; return 0
    }
    git -C "$root" rev-list --count "origin/$branch..HEAD" 2>/dev/null || echo "-1"
}

fw_push_state_clear() {
    rm -f "$(_fw_push_state_file "${1:-$PWD}")" 2>/dev/null || true
}

fw_push_state_record() {
    local root="${1:-$PWD}" outcome="$2" kind="${3:-unknown}" session="${4:-}"
    local file branch
    file=$(_fw_push_state_file "$root")
    branch=$(_fw_push_state_branch "$root")

    if [ "$outcome" = "success" ]; then
        fw_push_state_clear "$root"
        return 0
    fi

    command -v python3 >/dev/null 2>&1 || return 0
    mkdir -p "$(dirname "$file")" 2>/dev/null || return 0

    FW_PS_FILE="$file" FW_PS_BRANCH="$branch" FW_PS_KIND="$kind" \
    FW_PS_SESSION="$session" python3 - <<'PY' 2>/dev/null || true
import json, os, datetime

path = os.environ["FW_PS_FILE"]
branch = os.environ.get("FW_PS_BRANCH", "")
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

try:
    with open(path) as fh:
        state = json.load(fh)
    if not isinstance(state, dict):
        state = {}
except Exception:
    # A corrupt or absent file starts a fresh streak rather than aborting.
    # Losing one failure's history is survivable; refusing to record any
    # because a previous write was truncated is not.
    state = {}

# A streak belongs to a branch. Switching branches is a different question,
# not a continuation of this one.
if state.get("branch") != branch:
    state = {}

state["branch"] = branch
state["consecutive_failures"] = int(state.get("consecutive_failures", 0)) + 1
state.setdefault("first_failure_ts", now)
state["last_failure_ts"] = now
state["last_failure_kind"] = os.environ.get("FW_PS_KIND", "unknown")
session = os.environ.get("FW_PS_SESSION", "")
if session:
    state["last_session"] = session

tmp = path + ".tmp"
with open(tmp, "w") as fh:
    json.dump(state, fh, indent=2, sort_keys=True)
os.replace(tmp, path)
PY
}

fw_push_state_read() {
    local root="${1:-$PWD}" file branch unpushed
    file=$(_fw_push_state_file "$root")
    [ -f "$file" ] || return 0
    command -v python3 >/dev/null 2>&1 || return 0

    branch=$(_fw_push_state_branch "$root")
    unpushed=$(_fw_push_state_unpushed "$root" "$branch")

    # Self-heal: nothing outstanding means the streak is over, however it
    # ended. Clearing here (not only on our own successful push) is what makes
    # a manual `git push` from any checkout resolve the escalation.
    if [ "$unpushed" = "0" ]; then
        fw_push_state_clear "$root"
        return 0
    fi

    FW_PS_FILE="$file" FW_PS_BRANCH="$branch" FW_PS_UNPUSHED="$unpushed" \
    python3 - <<'PY' 2>/dev/null || true
import json, os

try:
    with open(os.environ["FW_PS_FILE"]) as fh:
        state = json.load(fh)
except Exception:
    raise SystemExit(0)

branch = os.environ.get("FW_PS_BRANCH", "")
if state.get("branch") != branch:
    raise SystemExit(0)

n = int(state.get("consecutive_failures", 0))
# One failure is not a pattern. The whole point of this rail is that it stays
# quiet on the ordinary case — a single failed push is visible in its own
# session's output and does not need a second voice. Escalate on repeat, which
# is the state nothing could previously see.
if n < 2:
    raise SystemExit(0)

print("stuck-push branch=%s failures=%d unpushed=%s since=%s kind=%s" % (
    branch, n, os.environ.get("FW_PS_UNPUSHED", "?"),
    state.get("first_failure_ts", "?"), state.get("last_failure_kind", "unknown"),
))
PY
}

# Human-facing sentence for a `stuck-push` line. Kept next to the producer so
# the wording and the fields cannot drift apart.
fw_push_state_advice() {
    local kind="$1"
    case "$kind" in
        killed)
            printf '%s' "The push was KILLED, not refused — the pre-push gate did not finish inside its timeout, so no verdict was ever produced. Measure the gate before retrying: \`time bin/fw audit --section structure\` (budget: tests/unit/t3062_prepush_runtime.bats). Raise FW_HANDOVER_PUSH_TIMEOUT only after you know the cost." ;;
        refused)
            printf '%s' "The push was REFUSED — a gate ran to completion and said no. Its message is in that session's output and is actionable as written. Re-run \`git push origin HEAD\` to see it again." ;;
        *)
            printf '%s' "Re-run \`git push origin HEAD\` in the foreground and read the failure — this streak was recorded without a classified cause." ;;
    esac
}
