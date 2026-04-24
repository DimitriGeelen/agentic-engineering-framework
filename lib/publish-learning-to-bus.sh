#!/bin/bash
# publish-learning-to-bus.sh — one-way publisher for T-1155 channel:learnings topic.
#
# Invoked by agents/context/lib/learning.sh::do_add_learning right after a
# new learning is persisted to .context/project/learnings.yaml. Mirrors the
# entry onto the bus so any peer project running a subscriber (T-1217 B2)
# sees it without polling the source project's filesystem.
#
# Invocation: env vars carry the payload — the caller sets L_ID, L_LEARNING,
# L_TASK, L_SOURCE, L_DATE, and optionally L_ORIGIN_PROJECT. No positional
# args — the caller already has the data and doesn't need to re-serialize.
#
# Design (mirrors T-1165 pickup-channel-bridge pattern):
#   - Non-fatal: any error path exits 0 so context add-learning stays safe.
#   - Capability-probing: `termlink channel post` (Tier-A, T-1160) first;
#     fall back to `termlink event broadcast` (universally present).
#   - Silent no-op if neither is available (old termlink, no termlink).
#   - Opt-out: FW_LEARNINGS_BUS_PUBLISH=0 disables entirely.
#
# See: T-1168 (this task), T-1074 (design rationale), T-1214 (federation
#      decision), T-1165 (sibling bridge pattern).

set -u
set -o pipefail

# Opt-out
[ "${FW_LEARNINGS_BUS_PUBLISH:-1}" = "0" ] && exit 0

L_ID="${L_ID:-}"
L_LEARNING="${L_LEARNING:-}"
L_TASK="${L_TASK:-}"
L_SOURCE="${L_SOURCE:-}"
L_DATE="${L_DATE:-$(date -u +%Y-%m-%d)}"

# Require at least the id + text
[ -n "$L_ID" ] || exit 0
[ -n "$L_LEARNING" ] || exit 0

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
LOG="${PROJECT_ROOT}/.context/working/.publish-learning-bus.log"
mkdir -p "$(dirname "$LOG")" 2>/dev/null || true

_log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$LOG" 2>/dev/null || true; }

# Missing termlink → silent no-op
if ! command -v termlink >/dev/null 2>&1; then
    _log "skip-no-termlink id=$L_ID"
    exit 0
fi

# Origin project identity: explicit override, else basename of PROJECT_ROOT
ORIGIN="${FW_ORIGIN_PROJECT:-${L_ORIGIN_PROJECT:-$(basename "$PROJECT_ROOT")}}"

# Origin hub fingerprint (T-1052 R1). Best-effort shell lookup of ~/.termlink/known_hubs
# first line for local hub. Empty string when not locatable — acceptable for publisher side.
HUB_FP=""
if [ -r "${HOME:-/tmp}/.termlink/known_hubs" ]; then
    HUB_FP=$(awk '/sha256:/{for(i=1;i<=NF;i++) if($i ~ /^sha256:/) {print $i; exit}}' \
              "${HOME:-/tmp}/.termlink/known_hubs" 2>/dev/null || true)
fi

TOPIC="channel:learnings"
MSG_TYPE="learning-${L_SOURCE:-unknown}"

# Build JSON payload. Use jq when available for safe escaping; fall back to a
# minimal ref-only envelope otherwise.
PAYLOAD=""
if command -v jq >/dev/null 2>&1; then
    PAYLOAD=$(jq -cn \
        --arg id "$L_ID" \
        --arg learning "$L_LEARNING" \
        --arg task "$L_TASK" \
        --arg source "$L_SOURCE" \
        --arg date "$L_DATE" \
        --arg origin "$ORIGIN" \
        --arg hub_fp "$HUB_FP" \
        '{origin_project:$origin, origin_hub_fingerprint:$hub_fp, learning_id:$id,
          learning:$learning, task:$task, source:$source, date:$date}' 2>/dev/null || true)
fi
if [ -z "$PAYLOAD" ]; then
    # Minimal ref-only envelope — safe even without jq
    PAYLOAD=$(printf '{"origin_project":"%s","learning_id":"%s","date":"%s"}' \
              "$ORIGIN" "$L_ID" "$L_DATE")
fi

# Prefer channel.post (T-1160 structured Tier-A). Payload path via --payload-from-file
# when available; else inline --payload; else stdin.
if termlink channel post --help >/dev/null 2>&1; then
    TMP_PAY=$(mktemp 2>/dev/null || echo /tmp/pub-learning-$$.json)
    printf '%s' "$PAYLOAD" > "$TMP_PAY" 2>/dev/null || true

    if termlink channel post "$TOPIC" --msg-type "$MSG_TYPE" \
           --payload-from-file "$TMP_PAY" >/dev/null 2>&1 \
       || termlink channel post "$TOPIC" --msg-type "$MSG_TYPE" \
           --payload "$PAYLOAD" >/dev/null 2>&1; then
        _log "posted via=channel.post topic=$TOPIC msg_type=$MSG_TYPE id=$L_ID origin=$ORIGIN"
        rm -f "$TMP_PAY" 2>/dev/null || true
        exit 0
    fi
    rm -f "$TMP_PAY" 2>/dev/null || true
    _log "channel.post-failed id=$L_ID — falling back to event.broadcast"
fi

# Fallback: event.broadcast (Tier-A, present in all known lineages)
if termlink event broadcast --help >/dev/null 2>&1; then
    if termlink event broadcast "$TOPIC" -p "$PAYLOAD" >/dev/null 2>&1; then
        _log "posted via=event.broadcast topic=$TOPIC msg_type=$MSG_TYPE id=$L_ID origin=$ORIGIN"
        exit 0
    fi
    _log "event.broadcast-failed id=$L_ID"
fi

_log "skip-no-method id=$L_ID — neither channel.post nor event.broadcast usable"
exit 0
