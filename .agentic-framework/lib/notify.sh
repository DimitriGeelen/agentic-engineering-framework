#!/bin/bash
# Framework push notification helper — thin wrapper over skills-manager alert dispatcher (T-708)
#
# Sends push notifications for framework events (Tier 0 blocks, task completions,
# audit failures, handovers, human AC ready). Uses the skills-manager (150) ntfy
# infrastructure via its alert dispatcher CLI.
#
# Usage:
#   source "$FRAMEWORK_ROOT/lib/notify.sh"
#   fw_notify "title" "message" [trigger] [category] [click_url]
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

# fw_notify_url — resolve the configured ntfy server base URL (T-2439)
#
# Portable, no host-local fallback: each installation points the framework at
# its own ntfy instance via `fw config set NTFY_URL <url>` (or FW_NTFY_URL env,
# or .framework.yaml). 4-tier resolution via fw_config. Echoes the URL, or
# nothing when unset — in which case the dispatcher uses its own default.
#
# Origin: the framework runs the dispatcher LOCALLY on whichever host calls it,
# and each host's dispatcher has its own default ntfy server. Inferring the
# target from one host's config (or letting it silently fall back to a host's
# local ntfy) shipped pushes to a decommissioned server. Making the target an
# explicit framework config makes the chosen instance unambiguous and visible.
fw_notify_url() {
    if ! command -v fw_config >/dev/null 2>&1; then
        if [ -n "${FRAMEWORK_ROOT:-}" ] && [ -f "$FRAMEWORK_ROOT/lib/config.sh" ]; then
            # shellcheck disable=SC1091
            . "$FRAMEWORK_ROOT/lib/config.sh" 2>/dev/null || return 0
        else
            return 0
        fi
    fi
    fw_config "NTFY_URL" "" 2>/dev/null
}

# fw_notify — send a push notification via skills-manager alert dispatcher
#
# Args:
#   $1 — title (required)
#   $2 — message (required)
#   $3 — trigger type (optional, default: "manual")
#   $4 — category for topic routing (optional, default: "framework")
#   $5 — click_url (optional, T-2438): class-correct Watchtower deep-link. When
#        non-empty it is appended to the message body on its own line; ntfy
#        renders body URLs as tappable, making the push one-tap-to-the-page.
#        Body-append is dispatcher-agnostic — no unknown flag is passed to the
#        dispatcher (its arg-handling lives across the 150-skills-manager project
#        boundary; the header-based Click: upgrade is homed there separately).
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
    local click_url="${5:-}"

    # Require at least title
    [ -n "$title" ] || return 0

    # T-2438: deep-link — append the class-correct Watchtower URL to the body so
    # the push is one-tap-to-the-page. Non-empty only; 4-arg callers unaffected.
    if [ -n "$click_url" ]; then
        if [ -n "$message" ]; then
            message="${message}"$'\n'"${click_url}"
        else
            message="$click_url"
        fi
    fi

    # Check dispatcher exists
    [ -f "$_SKILLS_DISPATCHER" ] || return 0

    # T-2439: resolve the configured ntfy server and export it to the dispatcher
    # so the framework publishes to the chosen instance — never a host-local
    # fallback. Empty = dispatcher's own default (backward-compatible). The
    # dispatcher reads os.environ.get("NTFY_URL"); we only prefix when non-empty.
    local _ntfy_url
    _ntfy_url=$(fw_notify_url)

    # Fire-and-forget — backgrounded, stderr suppressed
    if [ -n "$_ntfy_url" ]; then
        NTFY_URL="$_ntfy_url" python3 "$_SKILLS_DISPATCHER" \
            --trigger "$trigger" \
            --title "$title" \
            --message "${message:-$title}" \
            2>/dev/null &
    else
        python3 "$_SKILLS_DISPATCHER" \
            --trigger "$trigger" \
            --title "$title" \
            --message "${message:-$title}" \
            2>/dev/null &
    fi
}
