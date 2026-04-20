#!/usr/bin/env bash
# keylock.sh — Per-key serialization primitive using flock
# T-587: Keyed async queue for concurrent framework operations
#
# Usage:
#   source lib/keylock.sh
#   keylock_acquire "T-042"   # Blocks until lock acquired
#   # ... critical section ...
#   keylock_release "T-042"   # Releases lock
#
# Cross-key parallelism: locks on different keys do not block each other.
# Same-key serialization: locks on the same key execute sequentially.
# Stale lock cleanup: locks older than KEYLOCK_TIMEOUT (default 300s) are auto-released.

# Guard against double-sourcing
[ -n "${_KEYLOCK_LOADED:-}" ] && return 0
_KEYLOCK_LOADED=1

# Source config (may already be loaded by caller — guard protects against double-source)
FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$FRAMEWORK_ROOT/lib/config.sh"

# Configuration
KEYLOCK_DIR="${PROJECT_ROOT:-.}/.context/locks"
KEYLOCK_TIMEOUT=$(fw_config_int "KEYLOCK_TIMEOUT" 300)  # seconds before stale lock cleanup

# Track file descriptors per key for release
# declare -A requires bash 4+; fail gracefully
# shellcheck disable=SC2317 # exit 1 is fallback when return fails (sourced vs executed)
if ! declare -A _KEYLOCK_FDS 2>/dev/null; then
    echo "keylock: bash 4+ required for associative arrays" >&2
    return 1 2>/dev/null || exit 1
fi
_KEYLOCK_FD_COUNTER=200  # Start FDs at 200 to avoid collisions

# Sanitize key name for filesystem use
_keylock_path() {
    local key="$1"
    # Replace non-alphanumeric chars with dashes
    local safe_key
    safe_key=$(echo "$key" | tr -c 'a-zA-Z0-9_\n-' '-')
    echo "${KEYLOCK_DIR}/${safe_key}.lock"
}

# Clean stale locks older than KEYLOCK_TIMEOUT
_keylock_clean_stale() {
    local lock_file="$1"
    if [ -f "$lock_file" ]; then
        local now
        now=$(date +%s)
        local file_time
        file_time=$(stat -c %Y "$lock_file" 2>/dev/null || stat -f %m "$lock_file" 2>/dev/null || echo 0)
        local age=$((now - file_time))
        if [ "$age" -gt "$KEYLOCK_TIMEOUT" ]; then
            rm -f "$lock_file"
            return 0  # Stale lock cleaned
        fi
    fi
    return 1  # No stale lock
}

# Acquire a per-key lock.
#   keylock_acquire <key>           — block forever (default)
#   keylock_acquire <key> <seconds> — block up to N seconds, return 1 on timeout (T-1366)
keylock_acquire() {
    local key="${1:-}"
    local timeout="${2:-}"
    [ -z "$key" ] && { echo "keylock_acquire: key required" >&2; return 1; }

    mkdir -p "$KEYLOCK_DIR" 2>/dev/null

    local lock_file
    lock_file=$(_keylock_path "$key")

    # Clean stale lock if exists
    _keylock_clean_stale "$lock_file" 2>/dev/null || true

    # Touch lock file (creates if needed)
    touch "$lock_file"

    # Allocate file descriptor
    local fd=$_KEYLOCK_FD_COUNTER
    _KEYLOCK_FD_COUNTER=$((_KEYLOCK_FD_COUNTER + 1))

    # Open FD and acquire exclusive lock
    eval "exec ${fd}>\"${lock_file}\""
    if [ -n "$timeout" ]; then
        # Non-blocking with timeout: flock -w exits 1 on timeout
        if ! flock -w "$timeout" "$fd"; then
            # Close FD on timeout so caller can retry / fall through
            eval "exec ${fd}>&-"
            return 1
        fi
    else
        flock -x "$fd"
    fi

    # Store FD for release
    _KEYLOCK_FDS["$key"]=$fd

    return 0
}

# Release a per-key lock
keylock_release() {
    local key="$1"
    [ -z "$key" ] && { echo "keylock_release: key required" >&2; return 1; }

    local fd="${_KEYLOCK_FDS[$key]}"
    if [ -n "$fd" ]; then
        # Release lock by closing the file descriptor
        eval "exec ${fd}>&-"
        unset "_KEYLOCK_FDS[$key]"
    fi

    return 0
}
