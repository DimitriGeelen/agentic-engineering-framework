# shellcheck shell=bash
# T-2913 — shared rail producer for the messaging-toolkit scripts.
#
# Sourced (not executed) by agent-send.sh, agent-respond.sh,
# chat-arc-broadcast.sh and listener-heartbeat.sh so every `channel post`
# they make goes through the framework's lib/rail-identity.sh: the project's
# signing identity (RAIL_IDENTITY_FILE) and the canonical from_project label
# (T-2904, T-2905). Before this, all four called `termlink channel post`
# bare — host-signed, unlabeled — whatever `fw rail post` would have done.
#
# Usage:  rail_post <channel-post-args...>     (uses $TERMLINK, else termlink)
#
# These scripts are copied into consumer projects' scripts/ by fw upgrade, so
# the framework lib is located, not assumed:
#   FW_RAIL_IDENTITY_LIB > $FRAMEWORK_ROOT/lib > <project>/.agentic-framework/lib
#   > the framework repo this file sits in (lib/templates/scripts/../../lib).
# When none is found the post still goes out (the toolkit must keep working
# on a bare host) but says so on stderr — a silent fallback would be the same
# host-signed post this file exists to stop, wearing a fix's name.

_rail_post_find_lib() {
    local here proj c
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    proj="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
    for c in \
        "${FW_RAIL_IDENTITY_LIB:-}" \
        "${FRAMEWORK_ROOT:+$FRAMEWORK_ROOT/lib/rail-identity.sh}" \
        "$proj/.agentic-framework/lib/rail-identity.sh" \
        "$here/../.agentic-framework/lib/rail-identity.sh" \
        "$here/../../lib/rail-identity.sh"; do
        [ -n "$c" ] && [ -f "$c" ] && { printf '%s\n' "$c"; return 0; }
    done
    return 1
}

_RAIL_POST_LIB="$(_rail_post_find_lib || true)"
if [ -n "$_RAIL_POST_LIB" ]; then
    # rail-identity.sh finds lib/config.sh via FRAMEWORK_ROOT and reads
    # .framework.yaml from PROJECT_ROOT; default both from what we found.
    : "${FRAMEWORK_ROOT:=$(cd "$(dirname "$_RAIL_POST_LIB")/.." && pwd)}"
    : "${PROJECT_ROOT:=$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
    export FRAMEWORK_ROOT PROJECT_ROOT
    # shellcheck source=/dev/null
    . "$_RAIL_POST_LIB"
fi

rail_post() {
    local tl="${TERMLINK:-${TERMLINK_BIN:-termlink}}"
    if declare -F rail_post_exec >/dev/null 2>&1; then
        rail_post_exec "$tl" "$@"
    else
        echo "rail-post: WARNING — framework lib/rail-identity.sh not found; posting without project identity or from_project label (set FW_RAIL_IDENTITY_LIB)" >&2
        if [ -n "${RAIL_POST_TIMEOUT:-}" ] && command -v timeout >/dev/null 2>&1; then
            timeout "$RAIL_POST_TIMEOUT" "$tl" channel post "$@"
        else
            "$tl" channel post "$@"
        fi
    fi
}
