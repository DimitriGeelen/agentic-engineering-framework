#!/bin/bash
# lib/config.sh — 3-tier configuration resolution
#
# Pattern: explicit arg > FW_* env var > hardcoded default
#
# Usage:
#   source "$FRAMEWORK_ROOT/lib/config.sh"
#   CONTEXT_WINDOW=$(fw_config "CONTEXT_WINDOW" 200000)
#   DISPATCH_LIMIT=$(fw_config_int "DISPATCH_LIMIT" 2)
#
# Origin: T-817 inception (traceAI pattern adoption), T-819 build

[[ -n "${_FW_CONFIG_LOADED:-}" ]] && return 0
_FW_CONFIG_LOADED=1

# fw_config KEY DEFAULT [EXPLICIT_VALUE]
# Returns: EXPLICIT_VALUE if non-empty, else FW_KEY env var, else DEFAULT
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

    # Tier 3: Default
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

# fw_config_list — List all FW_* overrides (for fw doctor / Watchtower)
# Output: KEY=VALUE lines for each FW_* env var that is set
fw_config_list() {
    env | grep "^FW_" | sort
}

# Known settings registry — used by fw doctor and Watchtower /config
# Format: KEY|DEFAULT|DESCRIPTION
FW_CONFIG_REGISTRY=(
    "CONTEXT_WINDOW|200000|Context window size for budget enforcement (tokens)"
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
            current="$default"
            source="default"
        fi

        echo "${key}|${default}|${current}|${source}|${desc}"
    done
}
