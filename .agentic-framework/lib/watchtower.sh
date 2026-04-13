#!/bin/bash
# lib/watchtower.sh — Shared Watchtower URL detection and browser-open helper (T-974, T-1154)
#
# Centralizes port detection, host detection, and browser opening so that
# ALL scripts use the same logic. Eliminates hardcoded ports and duplicated
# browser-open code.
#
# Usage:
#   source "$FRAMEWORK_ROOT/lib/watchtower.sh"
#   url=$(_watchtower_url T-XXX)                    # get base URL with correct port
#   _watchtower_open "http://host:port/path"         # open in browser (desktop-user aware)
#
# Requires: PROJECT_ROOT (from paths.sh chain), config.sh for fw_config

# Source config for PORT setting (guard protects double-source)
source "${FRAMEWORK_ROOT:-.}/lib/config.sh"

[[ -n "${_FW_WATCHTOWER_LOADED:-}" ]] && return 0
_FW_WATCHTOWER_LOADED=1

# _watchtower_url [TASK_ID]
#
# Returns the base Watchtower URL (e.g., http://192.168.10.107:3002) on stdout.
# Resolution order: WATCHTOWER_URL env > PID file + ss > cwd match > port probe > config default.
#
# If TASK_ID is provided, port probing will verify the Watchtower instance knows
# that task (prevents cross-project false matches).
#
# Exit 0 + URL on stdout on success. Exit 1 if no Watchtower found.
_watchtower_url() {
    local task_id="${1:-}"

    # Fast path: explicit env override
    if [ -n "${WATCHTOWER_URL:-}" ]; then
        echo "$WATCHTOWER_URL"
        return 0
    fi

    local wt_port="" wt_host=""

    # Try 1a: PID file → ss port lookup
    # Check both PROJECT_ROOT and FRAMEWORK_ROOT for PID file (consumer vs framework)
    local pid_locations=(
        "$PROJECT_ROOT/.context/working/watchtower.pid"
        "${FRAMEWORK_ROOT:-}/.context/working/watchtower.pid"
    )
    for pid_file in "${pid_locations[@]}"; do
        if [ -f "$pid_file" ]; then
            local wt_pid
            wt_pid=$(cat "$pid_file" 2>/dev/null)
            if [ -n "$wt_pid" ] && kill -0 "$wt_pid" 2>/dev/null; then
                wt_port=$(ss -tlnp 2>/dev/null | grep "pid=$wt_pid" | grep -oP ':(\d+)\s' | tr -d ': ' | head -1)
                [ -n "$wt_port" ] && break
            fi
        fi
    done

    # Try 1b: Find Watchtower process by cwd match (no PID file needed)
    # This handles multi-project setups where each Watchtower has a different cwd.
    if [ -z "$wt_port" ]; then
        local fw_root="${FRAMEWORK_ROOT:-$PROJECT_ROOT/.agentic-framework}"
        local _pid
        for _pid in $(ss -tlnp 2>/dev/null | grep -oP 'pid=\K\d+' | sort -u); do
            local _cwd
            _cwd=$(readlink "/proc/$_pid/cwd" 2>/dev/null) || continue
            if [ "$_cwd" = "$fw_root" ] || [ "$_cwd" = "$PROJECT_ROOT" ]; then
                wt_port=$(ss -tlnp 2>/dev/null | grep "pid=$_pid" | grep -oP ':(\d+)\s' | tr -d ': ' | head -1)
                [ -n "$wt_port" ] && break
            fi
        done
    fi

    # Try 2: Probe common ports
    if [ -z "$wt_port" ]; then
        local default_port
        default_port=$(fw_config "PORT" 3000 2>/dev/null || echo 3000)

        # If we have a task ID, check task-specific endpoints first (prevents cross-project match)
        if [ -n "$task_id" ]; then
            for probe_port in "$default_port" 3000 3001 3002 3003 8080; do
                if curl -sf --max-time 2 "http://localhost:$probe_port/api/tasks/$task_id" >/dev/null 2>&1 \
                   || curl -sf --max-time 2 "http://localhost:$probe_port/inception/$task_id" >/dev/null 2>&1 \
                   || curl -sf --max-time 2 "http://localhost:$probe_port/review/$task_id" >/dev/null 2>&1; then
                    wt_port="$probe_port"
                    break
                fi
            done
        fi

        # Fallback: any responding Watchtower
        if [ -z "$wt_port" ]; then
            for probe_port in "$default_port" 3000 3001 3002 3003 8080; do
                if curl -sf --max-time 2 "http://localhost:$probe_port/" >/dev/null 2>&1; then
                    wt_port="$probe_port"
                    break
                fi
            done
        fi
    fi

    # Host detection
    wt_host=$(hostname -I 2>/dev/null | awk '{print $1}')
    wt_host="${wt_host:-$(hostname 2>/dev/null)}"
    wt_host="${wt_host:-localhost}"

    # Final port fallback
    wt_port="${wt_port:-$(fw_config "PORT" 3000 2>/dev/null || echo 3000)}"

    echo "http://${wt_host}:${wt_port}"
    return 0
}

# _watchtower_open URL
#
# Opens a URL in the default browser. When running as root (agent context),
# detects the desktop user and uses sudo to avoid Chromium's --no-sandbox error.
# Non-blocking, fail-silent — never blocks the calling script.
_watchtower_open() {
    local url="${1:-}"
    [ -z "$url" ] && return 1

    local _browser_opened=false

    # When running as root, open as the desktop user
    if [ "$(id -u)" = "0" ]; then
        local _desktop_user _desktop_uid
        _desktop_user=$(who 2>/dev/null | grep 'tty[0-9].*(:' | head -1 | awk '{print $1}')
        if [ -n "$_desktop_user" ]; then
            _desktop_uid=$(id -u "$_desktop_user" 2>/dev/null)
            if [ -n "$_desktop_uid" ]; then
                sudo -u "$_desktop_user" \
                    DISPLAY=:0 \
                    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${_desktop_uid}/bus" \
                    xdg-open "$url" >/dev/null 2>&1 &
                _browser_opened=true
            fi
        fi
    fi

    if ! $_browser_opened; then
        if command -v xdg-open >/dev/null 2>&1; then
            xdg-open "$url" >/dev/null 2>&1 &
        elif command -v open >/dev/null 2>&1; then
            open "$url" >/dev/null 2>&1 &
        fi
    fi
}
