#!/bin/bash
# hook-crashes.sh — acknowledge / count the hook crash log (T-4227)
#
# fw_hook_crash_trap (lib/config.sh) and fw_hook_run (lib/hook-dispatch.sh) append
# to .context/working/.hook-crashes.log; `fw doctor` WARNs on every line in it.
# Before T-4227 nothing ever removed a line, so once a crash was logged the doctor
# count could never return to zero. `acknowledge` moves the live entries to
# .hook-crashes.acknowledged.log (history kept, stamped with when they were
# acknowledged) and empties the live log.
#
# Usage (sourced or run directly; no bin/fw route yet):
#   bash lib/hook-crashes.sh count          — live (unacknowledged) entries
#   bash lib/hook-crashes.sh acknowledge    — archive live entries, empty the log
#   bash lib/hook-crashes.sh show           — print live entries

_fw_hook_crash_log() {
    echo "${PROJECT_ROOT:-.}/.context/working/.hook-crashes.log"
}

fw_hook_crashes_count() {
    local log
    log=$(_fw_hook_crash_log)
    if [ -s "$log" ]; then
        wc -l < "$log" | tr -d '[:space:]'
    else
        echo 0
    fi
}

fw_hook_crashes_acknowledge() {
    local log archive n stamp
    log=$(_fw_hook_crash_log)
    archive="${log%.log}.acknowledged.log"
    n=$(fw_hook_crashes_count)
    if [ "$n" -eq 0 ]; then
        echo "No unacknowledged hook crashes."
        return 0
    fi
    stamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    {
        echo "# acknowledged $stamp ($n entries)"
        cat "$log"
    } >> "$archive" || { echo "ERROR: could not write $archive" >&2; return 1; }
    : > "$log" || { echo "ERROR: could not empty $log" >&2; return 1; }
    echo "Acknowledged $n hook crash entries (archived to $archive)."
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        count)       fw_hook_crashes_count ;;
        acknowledge|ack) fw_hook_crashes_acknowledge ;;
        show)        log=$(_fw_hook_crash_log); [ -s "$log" ] && cat "$log" || echo "No unacknowledged hook crashes." ;;
        *)           echo "Usage: hook-crashes.sh {count|acknowledge|show}" >&2; exit 1 ;;
    esac
fi
