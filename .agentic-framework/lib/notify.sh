#!/bin/bash
# Framework push notification helper — thin wrapper over skills-manager alert dispatcher (T-708)
#
# Sends push notifications for framework events (Tier 0 blocks, task completions,
# audit failures, handovers, human AC ready). Uses the skills-manager (150) ntfy
# infrastructure via its alert dispatcher CLI.
#
# Usage:
#   source "$FRAMEWORK_ROOT/lib/notify.sh"
#   fw_notify "title" "message" [trigger] [category]
#
# Configuration:
#   NTFY_ENABLED — set to "true" to enable (default: disabled)
#
# Design: Fire-and-forget, backgrounded, never blocks the calling script.
# If skills-manager is unreachable, fails silently. Notifications are advisory.
#
# Related: T-707 (deep-dive), T-708 (this file), L-128 (cross-project coordination)

# Skills-manager alert dispatcher path
_SKILLS_DISPATCHER="${SKILLS_DISPATCHER:-/opt/150-skills-manager/skills/alerts/alert_dispatcher.py}"

# fw_notify — send a push notification via skills-manager alert dispatcher
#
# Args:
#   $1 — title (required)
#   $2 — message (required)
#   $3 — trigger type (optional, default: "manual")
#   $4 — category for topic routing (optional, default: "framework")
#
# Triggers recognized by skills-manager:
#   task_blocked    — Tier 0 approval needed (maps to CRITICAL)
#   manual          — general notification (maps to INFO)
#   health_check_failed — audit failure (maps to CRITICAL)
#   error_pattern   — recurring issue (maps to HIGH)
#
# Categories for topic routing:
#   framework       → ring20-framework topic
#   audit           → ring20-audit topic
#   infrastructure  → ring20-infrastructure topic
fw_notify() {
    # Disabled by default — opt-in only
    # Check env var first, then config file (T-710)
    local _ntfy_enabled="${NTFY_ENABLED:-}"
    if [ -z "$_ntfy_enabled" ] && [ -n "${PROJECT_ROOT:-}" ] && [ -f "$PROJECT_ROOT/.context/notify-config.yaml" ]; then
        _ntfy_enabled=$(python3 -c "import yaml; d=yaml.safe_load(open('$PROJECT_ROOT/.context/notify-config.yaml')); print(str(d.get('enabled','false')).lower())" 2>/dev/null || echo "false")
    fi
    [ "${_ntfy_enabled:-false}" = "true" ] || return 0

    local title="${1:-}"
    local message="${2:-}"
    local trigger="${3:-manual}"
    # shellcheck disable=SC2034  # reserved for dispatcher expansion
    local category="${4:-framework}"

    # Require at least title
    [ -n "$title" ] || return 0

    # Check dispatcher exists
    [ -f "$_SKILLS_DISPATCHER" ] || return 0

    # Fire-and-forget — backgrounded, stderr suppressed
    python3 "$_SKILLS_DISPATCHER" \
        --trigger "$trigger" \
        --title "$title" \
        --message "${message:-$title}" \
        2>/dev/null &
}
