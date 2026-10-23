#!/usr/bin/env bash
# T-3877: make sure this project's Watchtower runs once a session starts.
#
# Nothing started Watchtower after a reboot: on 2026-10-05 AEF's stayed down
# until started by hand and 055's for ~80 minutes, and every link handed out
# was dead. post-compact-resume.sh (SessionStart: startup, resume, compact)
# calls this DETACHED, so a session start never waits on it.
#
# The port is NOT chosen here: `bin/watchtower.sh start` applies T-3876's
# choose_port (explicit > configured PORT > last port > allocate, moves
# announced). Reference: 055's vendored T-467 patch.
#
# fw_watchtower_ensure — always returns 0. Running → no-op. Otherwise one
# start under a flock (several sessions start together after a reboot).
# FW_WATCHTOWER_ENSURE=0 disables it. Log: .context/working/watchtower-ensure.log
# Tests override the launcher with FW_WATCHTOWER_SH.

fw_watchtower_ensure() {
    [ "${FW_WATCHTOWER_ENSURE:-1}" = "0" ] && return 0
    [ -n "${FW_REVIEW_WORKER:-}" ] && return 0
    # T-3959: no dispatched worker needs a Watchtower; each one started its own
    # (bound 0.0.0.0, per worktree) and it outlived the worktree (1409).
    [ -n "${FW_DISPATCHED_WORKER:-}" ] && return 0
    local root="${PROJECT_ROOT:-}" fwr="${FRAMEWORK_ROOT:-}"
    [ -n "$root" ] && [ -d "$root/.context" ] || return 0
    local wt="${FW_WATCHTOWER_SH:-$fwr/bin/watchtower.sh}"
    [ -x "$wt" ] || [ -f "$wt" ] || return 0
    local dir="$root/.context/working" log lock
    mkdir -p "$dir" 2>/dev/null || return 0
    log="$dir/watchtower-ensure.log"; lock="$dir/.watchtower-ensure.lock"
    (
        flock -n 9 || { echo "$(date -u +%FT%TZ) skip: another ensure holds the lock" >>"$log"; exit 0; }
        if PROJECT_ROOT="$root" FRAMEWORK_ROOT="$fwr" bash "$wt" status >/dev/null 2>&1; then
            echo "$(date -u +%FT%TZ) ok: already running" >>"$log"
            exit 0
        fi
        echo "$(date -u +%FT%TZ) not running: starting" >>"$log"
        # T-4706: a pid or url file means it HAD been running — this is an outage, not a
        # first start. Capture it before start rewrites the triple.
        local _last_pid="" _down_since="" _outage=0
        if [ -f "$dir/watchtower.pid" ] || [ -f "$dir/watchtower.url" ]; then
            _outage=1
            _last_pid=$(tr -cd '0-9' < "$dir/watchtower.pid" 2>/dev/null || true)
            # The server writes its log on every request, so the log's mtime is the
            # last moment it was seen alive.
            [ -f "$dir/watchtower.log" ] && _down_since=$(date -u -d "@$(stat -c %Y "$dir/watchtower.log")" +%FT%TZ 2>/dev/null || true)
        fi
        local _result=restarted
        if PROJECT_ROOT="$root" FRAMEWORK_ROOT="$fwr" bash "$wt" start >>"$log" 2>&1 </dev/null; then
            echo "$(date -u +%FT%TZ) started" >>"$log"
        else
            echo "$(date -u +%FT%TZ) START FAILED (rc=$?) — see above; fw doctor will WARN" >>"$log"
            _result=start-failed
        fi
        if [ "$_outage" = 1 ]; then
            printf '{"detected":"%s","down_since":"%s","last_pid":"%s","result":"%s","by":"%s"}\n' \
                "$(date -u +%FT%TZ)" "$_down_since" "$_last_pid" "$_result" "${FW_WATCHTOWER_ENSURE_BY:-session-start}" \
                >>"$dir/watchtower-outages.jsonl"
        fi
    ) 9>"$lock"
    return 0
}

# fw_watchtower_recent_outages [DAYS] — T-4706: print the outages ensure recorded in
# the last DAYS days (default FW_WATCHTOWER_OUTAGE_DAYS, else 7), oldest first, as
# "detected=… down_since=… last_pid=… result=…". rc 0 when there is at least one.
# Read by `fw doctor`, which WARNs: an outage nobody saw is the T-4706 failure.
fw_watchtower_recent_outages() {
    local days="${1:-${FW_WATCHTOWER_OUTAGE_DAYS:-7}}" root="${PROJECT_ROOT:-}" f cutoff
    [[ "$days" =~ ^[0-9]+$ ]] || days=7
    f="$root/.context/working/watchtower-outages.jsonl"
    [ -n "$root" ] && [ -s "$f" ] || return 1
    cutoff=$(date -u -d "-${days} days" +%FT%TZ 2>/dev/null) || return 1
    awk -v c="$cutoff" '
        { d=$0; sub(/.*"detected":"/, "", d); sub(/".*/, "", d)
          if (d >= c) {
              s=$0; sub(/.*"down_since":"/, "", s); sub(/".*/, "", s)
              p=$0; sub(/.*"last_pid":"/, "", p); sub(/".*/, "", p)
              r=$0; sub(/.*"result":"/, "", r); sub(/".*/, "", r)
              print "detected=" d " down_since=" s " last_pid=" p " result=" r; n++ } }
        END { exit (n > 0 ? 0 : 1) }' "$f"
}
