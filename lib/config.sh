#!/bin/bash
# lib/config.sh — 3-tier configuration resolution
#
# Pattern: explicit arg > FW_* env var > hardcoded default
#
# Usage:
#   source "$FRAMEWORK_ROOT/lib/config.sh"
#   CONTEXT_WINDOW=$(fw_config "CONTEXT_WINDOW" 300000)
#   DISPATCH_LIMIT=$(fw_config_int "DISPATCH_LIMIT" 2)
#
# Origin: T-817 inception (traceAI pattern adoption), T-819 build

[[ -n "${_FW_CONFIG_LOADED:-}" ]] && return 0
_FW_CONFIG_LOADED=1

# _fw_config_file_val KEY — read a value from .framework.yaml
# Supports dot-notation (e.g., watchtower.port) and flat keys
_fw_config_file_val() {
    local key="$1"
    local config_file="${PROJECT_ROOT:-.}/.framework.yaml"

    # Skip if no config file
    [ -f "$config_file" ] || return 1

    # For simple (non-dotted) keys, use grep for speed (no Python startup)
    if [[ "$key" != *.* ]]; then
        local val
        val=$(grep "^${key}:" "$config_file" 2>/dev/null | head -1 | sed "s/^${key}:[[:space:]]*//;s/[[:space:]]*$//;s/^[\"']//;s/[\"']$//")
        [ -n "$val" ] && echo "$val" && return 0
        return 1
    fi

    # For dotted keys, use Python for nested YAML lookup
    python3 - "$config_file" "$key" << 'PYVAL' 2>/dev/null
import yaml, sys
try:
    with open(sys.argv[1]) as f:
        data = yaml.safe_load(f) or {}
    parts = sys.argv[2].split('.')
    current = data
    for part in parts:
        if isinstance(current, dict) and part in current:
            current = current[part]
        else:
            sys.exit(1)
    print(current)
except:
    sys.exit(1)
PYVAL
}

# fw_config KEY DEFAULT [EXPLICIT_VALUE]
# Returns: EXPLICIT_VALUE if non-empty, else FW_KEY env var, else .framework.yaml, else DEFAULT
fw_config() {
    local key="$1"
    local default="$2"
    local explicit="${3:-}"

    # Tier 1: Explicit argument wins
    if [ -n "$explicit" ]; then
        echo "$explicit"
        return
    fi

    # Tier 2: Environment variable (FW_ prefix)
    local env_var="FW_${key}"
    local env_val="${!env_var:-}"
    if [ -n "$env_val" ]; then
        echo "$env_val"
        return
    fi

    # Tier 3: .framework.yaml persistent config (T-891)
    local file_val
    file_val=$(_fw_config_file_val "$key" 2>/dev/null) && [ -n "$file_val" ] && {
        echo "$file_val"
        return
    }

    # Tier 4: Default
    echo "$default"
}

# fw_config_int KEY DEFAULT [EXPLICIT_VALUE]
# Same as fw_config but validates the result is a non-negative integer.
# Falls back to DEFAULT on invalid input.
fw_config_int() {
    local key="$1"
    local default="$2"
    local val
    val=$(fw_config "$@")
    if ! [[ "$val" =~ ^[0-9]+$ ]]; then
        echo "WARNING: FW_$key must be a non-negative integer, got '$val' — using default $default" >&2
        echo "$default"
        return
    fi
    echo "$val"
}

# fw_hook_crash_trap — Install EXIT trap for PreToolUse hooks (T-821)
# Distinguishes "hook crashed" (exit 1) from "hook blocked" (exit 2).
# Uses EXIT (not ERR) so it only fires when the script actually exits,
# not on every intermediate command failure.
fw_hook_crash_trap() {
    local hook_name="${1:-unknown}"
    local crash_log="${PROJECT_ROOT:-.}/.context/working/.hook-crashes.log"
    # shellcheck disable=SC2154 # _exit is assigned by $? inside the trap
    trap '
        _exit=$?
        if [ $_exit -ne 0 ] && [ $_exit -ne 2 ]; then
            echo "" >&2
            echo "╔══════════════════════════════════════════════════╗" >&2
            echo "║  HOOK CRASHED: '"$hook_name"' (exit $_exit)            ║" >&2
            echo "║  This is a hook malfunction, NOT a policy block ║" >&2
            echo "║  Action: Report to human, run fw doctor         ║" >&2
            echo "╚══════════════════════════════════════════════════╝" >&2
            echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] CRASH: '"$hook_name"' exit=$_exit" >> "'"$crash_log"'" 2>/dev/null
        fi
    ' EXIT
}

# fw_config_list — List all FW_* overrides (for fw doctor / Watchtower)
# Output: KEY=VALUE lines for each FW_* env var that is set
fw_config_list() {
    env | grep "^FW_" | sort
}

# Known settings registry — used by fw doctor and Watchtower /config
# Format: KEY|DEFAULT|DESCRIPTION
FW_CONFIG_REGISTRY=(
    "CONTEXT_WINDOW|300000|Context window size for budget enforcement (tokens)"
    "PORT|3000|Watchtower web UI listen port"
    "DISPATCH_LIMIT|2|Agent tool dispatches before TermLink gate triggers"
    "BUDGET_RECHECK_INTERVAL|5|Re-read transcript every N tool calls"
    "BUDGET_STATUS_MAX_AGE|90|Max seconds before cached budget status is stale"
    "TOKEN_CHECK_INTERVAL|5|Check token usage every N tool calls"
    "HANDOVER_COOLDOWN|600|Seconds between auto-handover triggers"
    "STALE_TASK_DAYS|7|Days before a task is flagged stale"
    "MAX_RESTARTS|5|Max consecutive auto-restarts"
    "SAFE_MODE|0|Bypass task gate (escape hatch)"
    "CALL_WARN|40|Tool-call count threshold for warn level (fallback)"
    "CALL_URGENT|60|Tool-call count threshold for urgent level (fallback)"
    "CALL_CRITICAL|80|Tool-call count threshold for critical level (fallback)"
    "BASH_TIMEOUT|300000|Default Bash tool timeout in milliseconds"
    "KEYLOCK_TIMEOUT|300|Per-key lock stale cleanup timeout in seconds"
    "TERMLINK_WORKER_TIMEOUT|600|TermLink worker execution timeout in seconds"
    "HANDOVER_DEDUP_COOLDOWN|300|Seconds between duplicate handover detection"
    "INCEPTION_COMMIT_LIMIT|2|Max exploration commits before inception decision gate"
)

# fw_config_registry — Print all known settings with current values
# Output: KEY|DEFAULT|CURRENT|SOURCE|DESCRIPTION
fw_config_registry() {
    for entry in "${FW_CONFIG_REGISTRY[@]}"; do
        local key default desc
        key=$(echo "$entry" | cut -d'|' -f1)
        default=$(echo "$entry" | cut -d'|' -f2)
        desc=$(echo "$entry" | cut -d'|' -f3)

        local env_var="FW_${key}"
        local env_val="${!env_var:-}"
        local current source

        if [ -n "$env_val" ]; then
            current="$env_val"
            source="env"
        else
            local file_val
            if file_val=$(_fw_config_file_val "$key" 2>/dev/null) && [ -n "$file_val" ]; then
                current="$file_val"
                source="file"
            else
                current="$default"
                source="default"
            fi
        fi

        echo "${key}|${default}|${current}|${source}|${desc}"
    done
}
