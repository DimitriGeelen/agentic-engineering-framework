#!/bin/bash
# lib/pid-alive.sh — the one zombie-aware pid liveness test (T-4306, T-4337).
#
# `kill -0` alone succeeds on a ZOMBIE (exited, never reaped by its parent),
# so a bare `kill -0` reads a dead Watchtower as running. T-4306 fixed this in
# bin/watchtower.sh; T-4337 moved the helper here so lib/watchtower.sh and
# lib/watchtower-staleness.sh use the same test instead of bare `kill -0`.

[[ -n "${_FW_PID_ALIVE_LOADED:-}" ]] && return 0
_FW_PID_ALIVE_LOADED=1

# fw_pid_alive PID — rc 0 iff PID exists and is not a zombie.
fw_pid_alive() {
    local pid="$1" state=""
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null || return 1
    if [ -r "/proc/$pid/stat" ]; then
        # comm may contain spaces/parens: the state follows the LAST ')'.
        state=$(sed 's/.*) //' "/proc/$pid/stat" 2>/dev/null | cut -d' ' -f1) || true
    else
        state=$(ps -o stat= -p "$pid" 2>/dev/null | tr -d '[:space:]') || true
    fi
    # T-5078: an empty read means the process vanished between `kill -0` and the
    # state read (its parent reaped the zombie). Empty is not "Z", so without this
    # re-check a process that no longer exists read as alive, and `watchtower stop`
    # reported "Failed to stop" for a stop that had worked.
    if [ -z "$state" ]; then
        kill -0 "$pid" 2>/dev/null || return 1
    fi
    [ "${state:0:1}" != "Z" ]
}

# ── T-5267 (G-135): pid identity — is this pid still the process that wrote the file? ──
# Shell mirror of lib/proc_identity.py; same rule, same `<pidfile>.identity` format
# (key=value: pid, start_ticks, cmd_marker). A parity test runs both on the same cases.
# FW_PROC_ROOT overrides /proc (tests).

# _fw_proc_start_ticks PID — field 22 of /proc/PID/stat (after the LAST ')'), or rc 1.
_fw_proc_start_ticks() {
    local root="${FW_PROC_ROOT:-/proc}" rest
    [ -r "$root/$1/stat" ] || return 1
    rest=$(sed 's/.*) //' "$root/$1/stat" 2>/dev/null) || return 1
    # rest starts at field 3 (state); field 22 is the 20th word
    set -- $rest
    [ "$#" -ge 20 ] || return 1
    shift 19
    case "$1" in ''|*[!0-9]*) return 1 ;; esac
    printf '%s\n' "$1"
}

# _fw_proc_cmdline PID — the NUL-joined cmdline with spaces, or empty.
_fw_proc_cmdline() {
    local root="${FW_PROC_ROOT:-/proc}"
    [ -r "$root/$1/cmdline" ] || return 0
    tr '\0' ' ' < "$root/$1/cmdline" 2>/dev/null || true
}

_fw_have_proc() {
    local root="${FW_PROC_ROOT:-/proc}"
    [ -d "$root/self" ] || [ -f "$root/1/stat" ]
}

_fw_boot_id() {
    local root="${FW_PROC_ROOT:-/proc}"
    tr -d '[:space:]' < "$root/sys/kernel/random/boot_id" 2>/dev/null || true
}

# fw_pid_identity_write PIDFILE PID MARKER — record PID's identity beside PIDFILE.
# MARKER is recorded only when PID's cmdline contains it now (same rule as Python).
# rc 1 (and any old identity removed) when the pid's start time cannot be read.
fw_pid_identity_write() {
    local pf="$1" pid="$2" marker="${3:-}" st tmp cl
    st=$(_fw_proc_start_ticks "$pid") || { rm -f "$pf.identity"; return 1; }
    if [ -n "$marker" ]; then
        cl=$(_fw_proc_cmdline "$pid")
        case "$cl" in *"$marker"*) ;; *) marker="" ;; esac
    fi
    tmp="$pf.identity.tmp.${BASHPID:-$$}-$RANDOM$RANDOM"
    printf 'pid=%s\nstart_ticks=%s\nboot_id=%s\ncmd_marker=%s\n' \
        "$pid" "$st" "$(_fw_boot_id)" "$marker" > "$tmp" 2>/dev/null \
        && mv -f "$tmp" "$pf.identity" 2>/dev/null && return 0
    rm -f "$tmp"
    return 1
}

# fw_pid_same_process PIDFILE PID MARKER
#   rc 0 same process, 1 different (reused pid / previous boot / gone / legacy without
#   a marker match), 2 cannot tell (no /proc on this host). Reason printed on stdout.
#   With a recorded identity for PID the RECORDED marker is checked; MARKER is the
#   legacy rule's marker (a pid file with no identity is never "same" without it).
fw_pid_same_process() {
    local pf="$1" pid="$2" marker="${3:-}" rec_pid="" rec_st="" rec_boot="" rec_mark="" k v now cl cur_boot
    if ! _fw_have_proc; then
        echo "no /proc on this host: identity cannot be checked"; return 2
    fi
    case "$pid" in ''|*[!0-9]*|0) echo "no pid"; return 1 ;; esac
    if [ -n "$pf" ] && [ -r "$pf.identity" ]; then
        while IFS='=' read -r k v; do
            case "$k" in
                pid) rec_pid="$v" ;;
                start_ticks) rec_st="$v" ;;
                boot_id) rec_boot="$v" ;;
                cmd_marker) rec_mark="$v" ;;
            esac
        done < "$pf.identity"
    fi
    if ! now=$(_fw_proc_start_ticks "$pid"); then
        echo "pid $pid is not running"; return 1
    fi
    if [ "$rec_pid" = "$pid" ] && [ -n "$rec_st" ]; then
        cur_boot=$(_fw_boot_id)
        if [ -n "$rec_boot" ] && [ -n "$cur_boot" ] && [ "$rec_boot" != "$cur_boot" ]; then
            echo "pid $pid: pid file is from a previous boot"; return 1
        fi
        if [ "$rec_st" != "$now" ]; then
            echo "pid $pid was reused: start_ticks $now != recorded $rec_st"; return 1
        fi
        if [ -n "$rec_mark" ]; then
            cl=$(_fw_proc_cmdline "$pid")
            case "$cl" in *"$rec_mark"*) ;; *) echo "pid $pid cmdline lacks '$rec_mark'"; return 1 ;; esac
        fi
        echo "identity matches"; return 0
    fi
    if [ -z "$marker" ]; then
        echo "pid $pid: no recorded identity and no cmdline marker to check"; return 1
    fi
    cl=$(_fw_proc_cmdline "$pid")
    case "$cl" in
        *"$marker"*) echo "legacy pid file: cmdline contains '$marker'"; return 0 ;;
    esac
    echo "legacy pid file: pid $pid cmdline lacks '$marker'"; return 1
}
