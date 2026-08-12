#!/bin/bash
# T-2938: does the RUNNING Watchtower actually run the code on disk?
#
# Origin. The operator recorded GO on T-2925 through Watchtower. The decision
# was written to the task file and then refused at the commit boundary by the
# G-052 duplicate-task-ID scan — the exact failure T-2864 had already fixed in
# `web/blueprints/inception.py` four days earlier. Both facts were true at once:
# the fix was on disk, and the defect was in the running process. The Watchtower
# serving :3001 had been started on Aug 6 23:44; the fix landed Aug 8 09:38, and
# Flask runs with `debug=False` here, so there is no reloader. Six days of a
# process holding bytes nobody could see.
#
# Why doctor could not see it. The existing triple check (bin/fw ~:1892) asks
# whether the pid is alive and whether /api/_identity claims our PROJECT_ROOT.
# Both were true the whole time. `OK  Watchtower running` is a liveness claim
# being read as a currency claim — the same shape as the cron chain's
# registry → generated → deployed ladder (L-364), where "wired" is not
# "deployed" and "deployed" is not "executable". This is the web analogue of
# that third rung, which CLAUDE.md records as having no automated gate.
#
# Blast radius is never one fix. Five commits touched web/ inside that window
# (T-2842, T-2864, T-2885, T-2904, T-2905). Two of them — T-2904, T-2905 — were
# human-owned and sitting in the review queue for the operator to verify IN the
# Watchtower that was not running them. A [REVIEW] verdict taken against a stale
# process is worse than no verdict: it looks like evidence.
#
# Deliberately mtime-based, not content-based. A false WARN costs one restart;
# a missed WARN costs another six-day window. `git checkout` / `fw vendor` touch
# files without changing content and will WARN spuriously — accepted, because
# the failure it guards is silent and the remedy is cheap. (Contrast T-2290,
# which moved the MCP manifest check the other way, mtime → content compare:
# there the stale-WARN fired constantly and the drift was loud. Here the drift
# is silent, so the bias inverts.)
#
# Portability: no `find -newermt` (GNU accepts @epoch, BSD does not parse it the
# same way) and no bare `stat -c` (BSD wants -f %m). Both flavours are probed.

# Epoch seconds at which $1 started. Echoes nothing and returns 1 when it cannot
# be determined — every caller must treat "unknown" as "do not warn", because a
# guess here produces a WARN on every doctor run.
watchtower_process_start_epoch() {
    local pid="$1" elapsed now
    [ -n "$pid" ] || return 1
    kill -0 "$pid" 2>/dev/null || return 1

    # `ps -o etimes=` (seconds since start) exists on Linux and modern BSD/macOS.
    elapsed=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d '[:space:]')
    if [ -n "$elapsed" ] && [ "$elapsed" -ge 0 ] 2>/dev/null; then
        now=$(date +%s)
        echo $(( now - elapsed ))
        return 0
    fi

    # Fallback: the /proc entry's mtime is the process start time on Linux.
    if [ -d "/proc/$pid" ]; then
        local st
        st=$(stat -c %Y "/proc/$pid" 2>/dev/null || stat -f %m "/proc/$pid" 2>/dev/null)
        if [ -n "$st" ]; then
            echo "$st"
            return 0
        fi
    fi
    return 1
}

# mtime of $1 in epoch seconds, GNU then BSD. Silent + rc 1 when unreadable.
_wt_file_mtime() {
    local f="$1" m
    m=$(stat -c %Y "$f" 2>/dev/null) || m=$(stat -f %m "$f" 2>/dev/null) || return 1
    [ -n "$m" ] || return 1
    echo "$m"
}

# Source files under $2 (default: $PROJECT_ROOT/web) modified after process $1
# started. Prints one path per line, newest first is NOT guaranteed — callers
# show a sample, so ordering is not load-bearing.
#
# rc 0 = at least one newer file (the WARN condition)
# rc 1 = none newer, or the start time could not be determined
watchtower_stale_sources() {
    local pid="$1"
    local web_dir="${2:-${PROJECT_ROOT:-.}/web}"
    local started file mtime found=1

    [ -d "$web_dir" ] || return 1
    started=$(watchtower_process_start_epoch "$pid") || return 1

    # Only the file types the server actually loads. __pycache__ is excluded:
    # it is written BY the running process, so it is newer than the process by
    # construction and would make this check fire always — i.e. never.
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        mtime=$(_wt_file_mtime "$file") || continue
        if [ "$mtime" -gt "$started" ] 2>/dev/null; then
            echo "$file"
            found=0
        fi
    done <<EOF
$(find "$web_dir" -type f \( -name '*.py' -o -name '*.html' -o -name '*.css' -o -name '*.js' \) \
    -not -path '*/__pycache__/*' 2>/dev/null)
EOF

    return $found
}
