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
        if PROJECT_ROOT="$root" FRAMEWORK_ROOT="$fwr" bash "$wt" start >>"$log" 2>&1 </dev/null; then
            echo "$(date -u +%FT%TZ) started" >>"$log"
        else
            echo "$(date -u +%FT%TZ) START FAILED (rc=$?) — see above; fw doctor will WARN" >>"$log"
        fi
    ) 9>"$lock"
    return 0
}
