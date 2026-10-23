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
# WATCHTOWER_ENSURE: 0 (.framework.yaml, `fw config set`) or FW_WATCHTOWER_ENSURE=0
# disables it (T-4711); a systemd-managed Watchtower is left to systemd. Log: .context/working/watchtower-ensure.log
# Tests override the launcher with FW_WATCHTOWER_SH.

# _fw_watchtower_ensure_enabled — T-4711: WATCHTOWER_ENSURE is a config key (registry
# default 1). FW_WATCHTOWER_ENSURE in the environment wins, then .framework.yaml.
# Read here without fw_config: post-compact-resume.sh sources this without lib/config.sh.
_fw_watchtower_ensure_enabled() {
    local v="${FW_WATCHTOWER_ENSURE:-}" cfg="${PROJECT_ROOT:-.}/.framework.yaml"
    if [ -z "$v" ] && [ -f "$cfg" ]; then
        v=$( { grep -E '^WATCHTOWER_ENSURE:' "$cfg" 2>/dev/null || true; } | head -1 \
            | sed "s/^WATCHTOWER_ENSURE:[[:space:]]*//;s/[[:space:]]*\(#.*\)\{0,1\}$//;s/^[\"']//;s/[\"']$//")
    fi
    [ "${v:-1}" != "0" ]
}

# _fw_wt_cgroup_unit <cgroup-file> — the systemd unit a process lives in: the last
# path component of its cgroup-v2 line (or of the last line on a v1-only host).
_fw_wt_cgroup_unit() {
    local f="$1" line
    [ -r "$f" ] || return 1
    line=$(grep -m1 '^0::' "$f" 2>/dev/null || tail -n1 "$f" 2>/dev/null) || return 1
    line="${line##*/}"
    [ -n "$line" ] && printf '%s\n' "$line"
}

# _fw_wt_unit_file <unit> — the unit file for <unit> in the unit dirs, if any.
_fw_wt_unit_dirs() {
    printf '%s\n' ${FW_WATCHTOWER_UNIT_DIRS:-/etc/systemd/system /run/systemd/system /usr/lib/systemd/system /lib/systemd/system ${HOME:+$HOME/.config/systemd/user}}
}

# _fw_wt_unit_runs_watchtower <file> [root] — the unit's ExecStart runs a Watchtower
# (watchtower.sh / `fw serve` / web.app). With <root>, it must be THIS project's:
# root appears in ExecStart or WorkingDirectory as a whole path.
_fw_wt_unit_runs_watchtower() {
    local f="$1" root="${2:-}" lines
    lines=$(grep -E '^[[:space:]]*(ExecStart|WorkingDirectory)[[:space:]]*=' "$f" 2>/dev/null) || return 1
    grep -E '^[[:space:]]*ExecStart' <<<"$lines" | grep -qE 'watchtower|web[./]app|fw[[:space:]]+serve' || return 1
    [ -z "$root" ] && return 0
    local r l
    for r in "$root" "$(readlink -f "$root" 2>/dev/null)"; do
        r="${r%/}"; [ -n "$r" ] || continue
        while IFS= read -r l; do
            l="${l%%[[:space:]]}"
            case "$l" in
                *"$r"/*|*"$r"[[:space:]\"\']*|*"$r") return 0 ;;
            esac
        done <<<"$lines"
    done
    return 1
}

# fw_watchtower_systemd_unit — T-4711. Prints the systemd *.service unit that manages
# this project's Watchtower; rc 1 when none does. The rule (recorded in T-4711):
#   1. the triple-file pid lives in a *.service cgroup that is NOT the caller's own unit
#      (a unit's own ExecStart may run `watchtower.sh start`) AND that unit is a
#      Watchtower unit (name contains "watchtower", or its unit file's ExecStart runs
#      one). The second clause keeps a pre-T-4706 server that merely inherited its
#      launcher's unit (cron.service, a cockpit service) from reading as managed.
#      aef-watchtower-*.scope is a scope, never a .service, so it never matches.
#   2. or a unit file in the unit dirs runs THIS project's Watchtower — this is what
#      covers systemd's restart window, when no managed process is alive to inspect.
# Seams: FW_WATCHTOWER_PROC_DIR (/proc), FW_WATCHTOWER_SELF_CGROUP (/proc/self/cgroup),
# FW_WATCHTOWER_UNIT_DIRS (space-separated).
fw_watchtower_systemd_unit() {
    local root="${PROJECT_ROOT:-}" proc="${FW_WATCHTOWER_PROC_DIR:-/proc}" pid unit own d f
    [ -n "$root" ] || return 1
    own=$(_fw_wt_cgroup_unit "${FW_WATCHTOWER_SELF_CGROUP:-/proc/self/cgroup}" || true)
    pid=$( { tr -cd '0-9' < "$root/.context/working/watchtower.pid"; } 2>/dev/null || true)
    if [ -n "$pid" ] && unit=$(_fw_wt_cgroup_unit "$proc/$pid/cgroup") \
        && [[ "$unit" == *.service ]] && [ "$unit" != "$own" ]; then
        if [[ "$unit" == *watchtower* ]]; then
            printf '%s\n' "$unit"; return 0
        fi
        while IFS= read -r d; do
            [ -f "$d/$unit" ] && _fw_wt_unit_runs_watchtower "$d/$unit" && { printf '%s\n' "$unit"; return 0; }
        done < <(_fw_wt_unit_dirs)
    fi
    while IFS= read -r d; do
        [ -d "$d" ] || continue
        for f in "$d"/*.service; do
            [ -f "$f" ] || continue
            [ "${f##*/}" = "$own" ] && continue
            _fw_wt_unit_runs_watchtower "$f" "$root" && { printf '%s\n' "${f##*/}"; return 0; }
        done
    done < <(_fw_wt_unit_dirs)
    return 1
}

fw_watchtower_ensure() {
    local root="${PROJECT_ROOT:-}" fwr="${FRAMEWORK_ROOT:-}"
    _fw_watchtower_ensure_enabled || return 0
    [ -n "${FW_REVIEW_WORKER:-}" ] && return 0
    # T-3959: no dispatched worker needs a Watchtower; each one started its own
    # (bound 0.0.0.0, per worktree) and it outlived the worktree (1409).
    [ -n "${FW_DISPATCHED_WORKER:-}" ] && return 0
    [ -n "$root" ] && [ -d "$root/.context" ] || return 0
    # T-4711: a systemd-managed Watchtower is systemd's to keep alive. Starting one
    # inside its restart window would leave a second, unmanaged server on the port
    # and systemd's own restart failing on it (ring20).
    local _unit
    if _unit=$(fw_watchtower_systemd_unit); then
        echo "watchtower: managed by systemd unit $_unit — ensure does nothing (T-4711)"
        mkdir -p "$root/.context/working" 2>/dev/null \
            && echo "$(date -u +%FT%TZ) skip: managed by systemd unit $_unit" >>"$root/.context/working/watchtower-ensure.log"
        return 0
    fi
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
