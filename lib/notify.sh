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
# Notifications are advisory, but failures are not silent (T-3866): background
# stderr is appended to .context/working/notify.log, `fw notify test` runs in
# the foreground, and `fw doctor` WARNs when the dispatcher cannot be imported.
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

    # Fire-and-forget — backgrounded. T-3866: stderr goes to a log, never
    # /dev/null; that is where the ImportError hid for the life of this file.
    local _log="/dev/null"
    if [ -n "${PROJECT_ROOT:-}" ] && [ -d "$PROJECT_ROOT/.context" ]; then
        mkdir -p "$PROJECT_ROOT/.context/working" 2>/dev/null && _log="$PROJECT_ROOT/.context/working/notify.log"
    fi
    fw_notify_send "$trigger" "$title" "${message:-$title}" </dev/null >/dev/null 2>>"$_log" &
}

# fw_notify_send — dispatch in the FOREGROUND and return the dispatcher's own
# exit status (T-3866). Reasons go to stderr. No enabled check: callers decide.
#
# The dispatcher is a package module with a relative import (and on some hosts
# no __main__), so it cannot be run as `python3 <file>`; lib/notify_dispatch.py
# imports it from its package root and calls dispatch_alert().
#
# Args: $1 trigger, $2 title, $3 message
fw_notify_send() {
    local trigger="${1:-manual}" title="${2:-}" message="${3:-}"
    [ -n "$title" ] || { echo "notify: no title" >&2; return 1; }
    [ -f "$_SKILLS_DISPATCHER" ] || { echo "notify: no alert dispatcher at $_SKILLS_DISPATCHER" >&2; return 1; }
    # T-2439: resolve the configured ntfy server and export it to the dispatcher
    # so the framework publishes to the chosen instance — never a host-local
    # fallback. Empty = dispatcher's own default (backward-compatible). The
    # dispatcher reads os.environ.get("NTFY_URL"); we only prefix when non-empty.
    local _ntfy_url
    _ntfy_url=$(fw_notify_url)
    local _helper
    _helper="$(dirname "${BASH_SOURCE[0]}")/notify_dispatch.py"
    if [ -n "$_ntfy_url" ]; then
        NTFY_URL="$_ntfy_url" python3 "$_helper" send "$_SKILLS_DISPATCHER" \
            --trigger "$trigger" --title "$title" --message "${message:-$title}"
    else
        python3 "$_helper" send "$_SKILLS_DISPATCHER" \
            --trigger "$trigger" --title "$title" --message "${message:-$title}"
    fi
}

# fw_notify_check — dry import of the dispatcher; sends nothing (T-3866).
# Exit 0 when it can run, 1 otherwise; prints the reason (stdout+stderr merged).
fw_notify_check() {
    [ -f "$_SKILLS_DISPATCHER" ] || { echo "missing: $_SKILLS_DISPATCHER"; return 1; }
    python3 "$(dirname "${BASH_SOURCE[0]}")/notify_dispatch.py" check "$_SKILLS_DISPATCHER" 2>&1
}

# fw_notify_doctor_check — fw doctor block (T-3866). Silent unless notifications
# are enabled for the project; then WARN when the dispatcher cannot be imported,
# because every push would be dropped. Uses the caller's colours and `warnings`.
fw_notify_doctor_check() {
    local _cfg="${PROJECT_ROOT:-}/.context/notify-config.yaml" _en="${NTFY_ENABLED:-}"
    if [ -z "$_en" ] && [ -f "$_cfg" ]; then
        _en=$(python3 -c "import yaml; d=yaml.safe_load(open('$_cfg')) or {}; print(str(d.get('enabled','false')).lower())" 2>/dev/null || echo "false")
    fi
    [ "${_en:-false}" = "true" ] || return 0
    local _why
    if _why=$(fw_notify_check); then
        echo -e "  ${GREEN:-}OK${NC:-}  Notify dispatcher importable"
    else
        echo -e "  ${YELLOW:-}WARN${NC:-}  Notifications enabled but the alert dispatcher cannot run — every push is dropped: $(echo "$_why" | tail -1)"
        echo -e "         Check: fw notify status"
        warnings=$((${warnings:-0} + 1))
    fi
}
