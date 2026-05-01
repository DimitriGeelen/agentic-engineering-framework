#!/usr/bin/env bash
# lib/hook-telemetry.sh — per-hook fire / failure counters (T-1628, B-2 of T-1626).
#
# Records every Claude Code hook invocation to flat `name=count` files so the
# threshold-escalation work in B-3 (T-1629) and `fw doctor` have observable
# signal that "non-blocking" hook failures are happening. Without this, hook
# breakage is invisible — see T-1626 inception (witness: ring20-dashboard
# 2026-04-30, dozens of `PostToolUse:Edit hook error / .agentic-framework/bin/fw:
# not found` flowed past while every framework health surface reported clean).
#
# Files (in $PROJECT_ROOT/.context/working/):
#   .hook-counter            — per-hook fire count, one `<hookname>=<count>` line
#   .hook-failure-counter    — per-hook non-zero-exit count, same format
#
# Performance budget: <5ms per fire (per T-1626 constraint). Achieved by a
# single awk subprocess per file with a small (typically <20-line) input.
# All errors are swallowed — telemetry must NEVER block a hook from running.

# fw_record_hook_fire <hookname> <exit_code>
#   Increment the per-hook fire counter. If exit_code != 0, also increment the
#   per-hook failure counter. Silent on all errors (telemetry never blocks).
fw_record_hook_fire() {
    local hookname="${1:-unknown}"
    local exit_code="${2:-0}"
    local working_dir="${PROJECT_ROOT:-.}/.context/working"
    [ -d "$working_dir" ] || return 0
    _fw_telemetry_increment "$working_dir/.hook-counter" "$hookname" 2>/dev/null || true
    if [ "$exit_code" != "0" ]; then
        _fw_telemetry_increment "$working_dir/.hook-failure-counter" "$hookname" 2>/dev/null || true
    fi
    return 0
}

# _fw_telemetry_increment <file> <key>
#   Read-modify-write of a flat `key=count\n` file. If the key already exists,
#   increments its value; otherwise appends `key=1`. Pure bash — no subprocess
#   fork — to keep per-fire overhead under the T-1626 5ms budget. On a typical
#   <20-line counter file this completes in well under 1ms.
_fw_telemetry_increment() {
    local file="$1"
    local key="$2"
    local -a lines
    local i k v
    local found=0
    if [ -f "$file" ]; then
        mapfile -t lines < "$file"
        for i in "${!lines[@]}"; do
            k="${lines[i]%%=*}"
            if [ "$k" = "$key" ]; then
                v="${lines[i]#*=}"
                lines[i]="$key=$((v + 1))"
                found=1
                break
            fi
        done
        [ "$found" = "0" ] && lines+=("$key=1")
        printf '%s\n' "${lines[@]}" > "$file"
    else
        printf '%s=1\n' "$key" > "$file"
    fi
}

# fw_hook_counter_get <kind> <hookname>
#   kind: fires|failures
#   Prints the current count for one hook, or "0" if absent. Used by B-3
#   (threshold escalation) and `fw doctor`. Read-only; safe in hot paths.
fw_hook_counter_get() {
    local kind="$1"
    local hookname="$2"
    local working_dir="${PROJECT_ROOT:-.}/.context/working"
    local file
    case "$kind" in
        fires)    file="$working_dir/.hook-counter" ;;
        failures) file="$working_dir/.hook-failure-counter" ;;
        *)        echo 0; return 0 ;;
    esac
    [ -f "$file" ] || { echo 0; return 0; }
    awk -v k="$hookname" -F= '$1==k {print $2; found=1; exit} END {if (!found) print 0}' "$file"
}
