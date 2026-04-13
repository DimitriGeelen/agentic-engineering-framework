#!/bin/bash
# lib/compat.sh — Cross-platform compatibility helpers
#
# Source this file to get portable shell functions that work on
# both GNU (Linux) and BSD (macOS) systems.
#
# Usage: source "$FRAMEWORK_ROOT/lib/compat.sh"

# Portable in-place sed edit.
# Works on both GNU sed (Linux) and BSD sed (macOS).
# Usage: _sed_i 'expression' file
_sed_i() {
    local expr="$1" file="$2"
    if [ ! -f "$file" ]; then
        echo "ERROR: _sed_i: file not found: $file" >&2
        return 1
    fi
    local tmp
    tmp=$(mktemp "${file}.XXXXXX") || return 1
    if sed "$expr" "$file" > "$tmp"; then
        mv "$tmp" "$file"
    else
        rm -f "$tmp"
        return 1
    fi
}

# Portable date-to-epoch conversion.
# Converts an ISO 8601 date string to Unix epoch seconds.
# Fallback chain: GNU date → BSD date → python3 (T-1134, T-1158)
# Usage: epoch=$(_date_to_epoch "2026-04-12T12:00:00Z")
_date_to_epoch() {
    local datestr="${1:-}"
    [ -z "$datestr" ] && echo "0" && return 1

    # Try GNU date (Linux)
    local result
    result=$(date -d "$datestr" +%s 2>/dev/null) && echo "$result" && return 0

    # Try BSD date (macOS) — needs format hint for ISO 8601
    result=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$datestr" +%s 2>/dev/null) && echo "$result" && return 0
    result=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$datestr" +%s 2>/dev/null) && echo "$result" && return 0

    # Fallback to python3
    result=$(python3 -c "
from datetime import datetime, timezone
import sys
try:
    dt = datetime.fromisoformat(sys.argv[1].replace('Z', '+00:00'))
    print(int(dt.timestamp()))
except Exception:
    print('0')
    sys.exit(1)
" "$datestr" 2>/dev/null) && echo "$result" && return 0

    echo "0"
    return 1
}

# Portable relative date calculation (e.g., "7 days ago").
# Usage: epoch=$(_date_relative "-7 days")
_date_relative() {
    local spec="${1:-}"
    [ -z "$spec" ] && echo "0" && return 1

    # Try GNU date
    local result
    result=$(date -d "$spec" +%s 2>/dev/null) && echo "$result" && return 0

    # Try BSD date — parse "N days ago" pattern
    local num unit
    if [[ "$spec" =~ ^-?([0-9]+)\ *(day|hour|minute|second)s?\ *(ago)?$ ]]; then
        num="${BASH_REMATCH[1]}"
        unit="${BASH_REMATCH[2]}"
        local flag
        case "$unit" in
            day) flag="-v-${num}d" ;;
            hour) flag="-v-${num}H" ;;
            minute) flag="-v-${num}M" ;;
            second) flag="-v-${num}S" ;;
        esac
        result=$(date "$flag" +%s 2>/dev/null) && echo "$result" && return 0
    fi

    # Fallback to python3
    result=$(python3 -c "
from datetime import datetime, timedelta, timezone
import sys, re
spec = sys.argv[1]
m = re.match(r'-?(\d+)\s*(day|hour|minute|second)s?\s*(ago)?', spec)
if m:
    n, unit = int(m.group(1)), m.group(2)
    delta = {'day': timedelta(days=n), 'hour': timedelta(hours=n),
             'minute': timedelta(minutes=n), 'second': timedelta(seconds=n)}[unit]
    print(int((datetime.now(timezone.utc) - delta).timestamp()))
else:
    print('0')
    sys.exit(1)
" "$spec" 2>/dev/null) && echo "$result" && return 0

    echo "0"
    return 1
}
