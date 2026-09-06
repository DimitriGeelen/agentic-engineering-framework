# shellcheck shell=bash
# T-3286 — shared agent_id resolver for agent-chat producers.
#
# Sourced (not executed) by agent-send.sh and agent-respond.sh so all three
# producer sites (turn post, receipt post, reply post) stamp
# `metadata.agent_id` from ONE resolution chain. Grain: INSTANCE identity
# (T-3287 D1, operator-ratified 2026-09-06) — two distinct agent-instances
# must NEVER collapse to one correspondent.
#
# Resolution chain, most-specific first:
#   1. FW_AGENT_ID          — explicit per-process env override. Set by the
#                             session itself for ITS OWN name (e.g. to match
#                             its /be-reachable logical id).
#   2. own TermLink session — `termlink whoami --json`: .session.display_name
#                             qualified by .session.id (the instance-unique
#                             part; display names can repeat, session ids
#                             cannot). NOT .session.identity_fingerprint —
#                             on a shared host that fingerprint is one host
#                             key signing for every co-resident agent
#                             (identity_shared_with > 1), i.e. the very
#                             collapse this resolver exists to prevent.
#   3. derived fallback     — <project-basename>-pid<PPID>: session-unique by
#                             construction (two co-resident processes never
#                             share a PID), legible enough to trace back.
#
# MUST NOT read host-shared listener state (~/.termlink/be-reachable.state or
# agent-presence heartbeats): those name ONE agent per host, and substituting
# the host's one listener id for every sender is the same one-stands-for-many
# collapse wearing a name (T-3286 A2).

resolve_agent_id() {
    local tl="${TERMLINK_BIN:-termlink}"

    # (1) explicit per-process override.
    if [ -n "${FW_AGENT_ID:-}" ]; then
        printf '%s\n' "$FW_AGENT_ID"
        return 0
    fi

    # (2) the sender's own TermLink session identity.
    local who="" display_name="" session_id=""
    who="$("$tl" whoami --json 2>/dev/null)" || who=""
    if [ -n "$who" ]; then
        display_name="$(printf '%s' "$who" | jq -r '.session.display_name // empty' 2>/dev/null)" || display_name=""
        session_id="$(printf '%s' "$who" | jq -r '.session.id // empty' 2>/dev/null)" || session_id=""
        if [ -n "$session_id" ]; then
            if [ -n "$display_name" ]; then
                printf '%s@%s\n' "$display_name" "$session_id"
            else
                printf '%s\n' "$session_id"
            fi
            return 0
        fi
    fi

    # (3) derived session-unique fallback: project + invoking process PID.
    local proj
    proj="$(basename "${PROJECT_ROOT:-$PWD}")"
    printf '%s-pid%s\n' "$proj" "$PPID"
    return 0
}
