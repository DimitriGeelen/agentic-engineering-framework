#!/bin/bash
# tools/wait-dispatch.sh — wait for a dispatched TermLink worker to be DONE.
#
# Usage: tools/wait-dispatch.sh <TASK-ID> <SESSION-NAME> [MAX_SECONDS]
#
# ── WHY THIS EXISTS (OBS-557, OBS-563) ──────────────────────────────────────────
#
# Twice in one day an orchestrator gated the next step on a signal the worker
# passes THROUGH on its way to finishing, and read whatever it happened to
# observe at that moment as a permanent state:
#
#   1. OBS-557 — waited on the FIRST `{"type":"result"}` line. A result line is a
#      YIELD, not completion; round 1 of a four-round run emitted 11 of them. Round
#      3 overlapped round 2 by ~50s.
#   2. OBS-563 — waited on the task file appearing in `.tasks/completed/`. That
#      move happens INSIDE `fw task update --status work-completed`, so it fires
#      before the worker's final commit. The tree observed in that window had the
#      entire deliverable staged and uncommitted, which was reported as a worker
#      governance failure and was really just a snapshot mid-`git`.
#
# The rule this file encodes:
#
#     A wait predicate must name a state the subject cannot pass THROUGH.
#
# Ask of any candidate signal: "can the worker be observed in this state and still
# have work left?" For both signals above the answer was yes.
#
# ── WHAT THIS WAITS ON ──────────────────────────────────────────────────────────
#
# The WORKER's terminal state, not the task's. Three accepting conditions, tried
# in this order, and the exit line always says which one fired because they mean
# different things:
#
#   exit-code    — `<dispatch_dir>/exit_code` exists. AUTHORITATIVE, and the one
#                  to use. run.sh's post-step writes it (with `finished_at` and
#                  T-3440's `close_state`) only after the `claude -p` process has
#                  returned, so the worker cannot be observed in this state with
#                  work left. This is the signal OBS-557 named as an unverified
#                  candidate — "the dispatch verb's own close_state file if one
#                  exists". It exists; measured on judge-arc-r1, which wrote
#                  exit_code=0, close_state=closed, finished_at=23:12:24Z.
#   worker-gone  — the session left `termlink list` without leaving an exit_code.
#                  The process died before run.sh's post-step ran, so there is no
#                  verdict to read — treat it as a crash until proven otherwise.
#   settled      — neither of the above, but the task is closed AND nothing is
#                  staged or modified for STABLE_CHECKS consecutive polls. Last
#                  resort, for a dispatch dir that cannot be located.
#
# Note that the session staying alive is NOT evidence of unfinished work:
# run.sh outlives the worker because its watchdog is `(sleep $TIMEOUT && kill …)`,
# so it always waits out the full timeout. judge-arc-r1 sat `ready` in
# `termlink list` for 38+ minutes after finishing. Waiting on the process to exit
# costs the remainder of the timeout for nothing — ~1h31m of dead waiting on one
# measured round.
#
# None of the three is a verdict on the WORK. `exit-code` tells you the process
# finished and how; `worker-gone` fires for a worker that died mid-edit exactly as
# for one that finished cleanly. The whole point of the two incidents above is
# that a signal which cannot tell those apart must not be read as if it could —
# so every exit path here says so explicitly.

set -u

TASK_ID="${1:?usage: wait-dispatch.sh <TASK-ID> <SESSION-NAME> [MAX_SECONDS]}"
SESSION="${2:?usage: wait-dispatch.sh <TASK-ID> <SESSION-NAME> [MAX_SECONDS]}"
MAX_SECONDS="${3:-7500}"

ROOT="${FRAMEWORK_ROOT:-$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)}"
POLL="${FW_WAIT_POLL:-45}"
# Consecutive clean polls before calling a still-alive worker settled. More than
# one, because a single clean observation is exactly the snapshot OBS-563 was.
STABLE_CHECKS="${FW_WAIT_STABLE_CHECKS:-3}"

_task_closed() {
    compgen -G "$ROOT/.tasks/completed/${TASK_ID}-*.md" > /dev/null
}

# The dispatch dir run.sh writes its post-step markers into. Overridable because
# the base path is a TermLink convention, not a framework guarantee.
DISPATCH_DIR="${FW_DISPATCH_DIR:-/tmp/tl-dispatch/$SESSION}"

_worker_exit_code() {
    [ -f "$DISPATCH_DIR/exit_code" ] || return 1
    cat "$DISPATCH_DIR/exit_code" 2>/dev/null
}

_worker_alive() {
    termlink list 2>/dev/null | grep -q -- "$SESSION"
}

# Anything staged, or anything modified outside the noise the framework itself
# rewrites on every run (monitors, audits, working state, metrics history).
_worker_tree_dirty() {
    local staged other
    staged=$(git -C "$ROOT" diff --cached --name-only 2>/dev/null | head -1)
    [ -n "$staged" ] && return 0
    other=$(git -C "$ROOT" status --porcelain 2>/dev/null \
        | grep -vE '^.. \.context/(monitors|audits|working)/' \
        | grep -vE '^.. \.context/project/metrics-history\.yaml' \
        | grep -vE '^.. (VERSION|\.agentic-framework/VERSION)$' \
        | head -1)
    [ -n "$other" ] && return 0
    return 1
}

deadline=$(( $(date +%s) + MAX_SECONDS ))
stable=0

while [ "$(date +%s)" -lt "$deadline" ]; do
    # (1) Authoritative: run.sh's post-step has recorded the worker's exit.
    if rc=$(_worker_exit_code); then
        cs=$(cat "$DISPATCH_DIR/close_state" 2>/dev/null || echo "?")
        fin=$(cat "$DISPATCH_DIR/finished_at" 2>/dev/null || echo "?")
        echo "DONE exit-code: ${SESSION} exit_code=${rc} close_state=${cs} finished_at=${fin}"
        if [ "$cs" = "incomplete" ]; then
            echo "NOTE: close_state=incomplete — the worker did NOT finish its task. Read its report before anything else."
        fi
        _task_closed || echo "NOTE: ${TASK_ID} is NOT closed — the worker exited without closing it."
        echo "NOTE: exit-code is terminal for the PROCESS, not a verdict on the WORK. Verify the deliverable."
        exit 0
    fi

    # (2) Died before the post-step could record anything.
    if ! _worker_alive; then
        if _task_closed; then
            echo "DONE worker-gone: ${SESSION} exited, ${TASK_ID} is closed"
        else
            echo "DONE worker-gone: ${SESSION} exited with ${TASK_ID} still OPEN — died, timed out, or parked"
        fi
        echo "NOTE: worker-gone is terminal for the PROCESS, not a verdict on the WORK. Verify the deliverable."
        exit 0
    fi

    if _task_closed && ! _worker_tree_dirty; then
        stable=$(( stable + 1 ))
        if [ "$stable" -ge "$STABLE_CHECKS" ]; then
            echo "DONE settled: ${TASK_ID} closed, tree clean for ${stable} consecutive poll(s), ${SESSION} still alive"
            echo "NOTE: settled means the worker stopped writing, not that the work is correct. Verify the deliverable."
            exit 0
        fi
    else
        stable=0
    fi

    sleep "$POLL"
done

echo "TIMEOUT after ${MAX_SECONDS}s: ${SESSION} still alive, ${TASK_ID} $(_task_closed && echo closed || echo open)"
echo "NOTE: a timeout is not a failure of the work — it is the absence of a verdict. Inspect, do not assume."
exit 1
