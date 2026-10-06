#!/usr/bin/env bash
# handover-lock.sh — the budget-critical auto-handover's re-entry lock (T-3917, G-110).
#
# checkpoint.sh (T-136) holds .context/working/.handover-in-progress while it runs
# the auto-handover, so a second PostToolUse call does not start a second one.
# Before T-3917 the lock was the literal "1", removed only on the normal path:
# any kill mid-handover (the claude-fw terminator's SIGTERM, a hook timeout)
# stranded it, and every later auto-handover was skipped SILENTLY — measured
# stale for ~4 months on AEF's own host and ~163 days on ring20-manager's.
#
# Now the lock records "<epoch> <pid>", and ONE predicate decides staleness for
# both the writer (checkpoint.sh) and the reporter (fw doctor):
#   - the writer's PID is no longer running, or
#   - the lock is older than 2 x FW_HANDOVER_TOTAL_TIMEOUT (floor 300 s), or
#   - it is a legacy lock (no epoch/pid) — judged by its file age alone.
#
# Usage:
#   source "$FRAMEWORK_ROOT/lib/handover-lock.sh"
#   fw_handover_lock_write "$lock"
#   if why=$(fw_handover_lock_stale "$lock"); then ... "$why" ...; fi

fw_handover_lock_max_age() {
    local total="${FW_HANDOVER_TOTAL_TIMEOUT:-60}" max
    case "$total" in ''|*[!0-9]*) total=60 ;; esac
    max=$((total * 2))
    [ "$max" -lt 300 ] && max=300
    echo "$max"
}

fw_handover_lock_write() {
    printf '%s %s\n' "$(date +%s)" "$$" > "$1"
}

# Exit 0 and print the reason when the lock at $1 is stale; exit 1 when it is
# live (or absent).
fw_handover_lock_stale() {
    local lock="$1" content epoch pid now age max
    [ -f "$lock" ] || return 1
    now=$(date +%s)
    max=$(fw_handover_lock_max_age)
    content=$(head -c 64 "$lock" 2>/dev/null | tr -d '\n')
    epoch=${content%% *}
    pid=${content#* }
    if [ "$epoch" = "$content" ] || ! [[ "$epoch" =~ ^[0-9]+$ ]] || ! [[ "$pid" =~ ^[0-9]+$ ]]; then
        # Legacy lock ("1") or garbage: only the file's own age is evidence.
        epoch=$(stat -c %Y "$lock" 2>/dev/null || echo "$now")
        age=$((now - epoch))
        if [ "$age" -gt "$max" ]; then
            echo "legacy lock (no pid), $((age / 86400)) day(s) old"
            return 0
        fi
        return 1
    fi
    age=$((now - epoch))
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "writer pid $pid is no longer running (lock ${age}s old)"
        return 0
    fi
    if [ "$age" -gt "$max" ]; then
        echo "lock ${age}s old, over the ${max}s bound"
        return 0
    fi
    return 1
}
