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
    [ "${state:0:1}" != "Z" ]
}
