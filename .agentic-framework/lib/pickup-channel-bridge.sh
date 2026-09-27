#!/bin/bash
# pickup-channel-bridge.sh — one-way bridge from shell pickup to T-1155 channel bus.
#
# Invoked by pickup_process_one (lib/pickup.sh) right after an envelope moves
# to processed/. Mirrors the envelope to the `framework:pickup` topic so online
# bus subscribers can observe pickups alongside existing shell consumers.
#
# Design (per T-1165 / T-1214 GO Option B — federate, don't converge):
#   - Non-fatal: any error path exits 0 so shell pickup stays portable.
#   - Posts via `termlink channel post` (Tier-A, T-1160, with --ensure-topic
#     auto-heal where supported). The legacy `event.broadcast` fallback was
#     removed (T-1814) — it emitted a primitive being retired (T-1166) and was
#     the lone live emitter resetting the cut's clean-window gate. Silent no-op
#     when channel.post is unavailable or fails (old termlink, no termlink,
#     transient hub error).
#   - Idempotent: SHA-256 of envelope contents is the dedup key. Re-invoking
#     on the same file is a recorded no-op.
#   - Opt-out: `FW_PICKUP_CHANNEL_BRIDGE=0` disables entirely.
#
# See: T-1155 (bus), T-1160 (channel.*), T-1214 (federation decision),
#      T-1215 (hub.capabilities — consumer will use this when available).

set -u
set -o pipefail

ENVELOPE="${1:-}"
[ -n "$ENVELOPE" ] || exit 0
[ -f "$ENVELOPE" ] || exit 0

# Opt-out
[ "${FW_PICKUP_CHANNEL_BRIDGE:-1}" = "0" ] && exit 0

# Logging (stderr of pickup_process_one is already noisy; go to file instead)
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
LOG="${PROJECT_ROOT}/.context/working/.pickup-bridge.log"
mkdir -p "$(dirname "$LOG")" 2>/dev/null || true

_log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$LOG" 2>/dev/null || true; }

BASENAME=$(basename "$ENVELOPE")

# Missing termlink → silent no-op (shell pickup still processed the envelope;
# the bridge is a pure enhancement)
if ! command -v termlink >/dev/null 2>&1; then
    _log "skip-no-termlink envelope=$BASENAME"
    exit 0
fi

# Dedup key: sha256 of envelope contents
SHA=""
if command -v sha256sum >/dev/null 2>&1; then
    SHA=$(sha256sum "$ENVELOPE" 2>/dev/null | awk '{print $1}')
elif command -v shasum >/dev/null 2>&1; then
    SHA=$(shasum -a 256 "$ENVELOPE" 2>/dev/null | awk '{print $1}')
fi
if [ -z "$SHA" ]; then
    _log "skip-no-sha envelope=$BASENAME"
    exit 0
fi

DEDUP_DIR="${PROJECT_ROOT}/.context/pickup/.bridge-posted"
mkdir -p "$DEDUP_DIR" 2>/dev/null || true
if [ -e "$DEDUP_DIR/$SHA" ]; then
    _log "dedup envelope=$BASENAME sha=$SHA"
    exit 0
fi

# Extract pickup type for msg_type field (bug-report|learning|feature-proposal|pattern|…)
P_TYPE=$(grep "^[[:space:]]*type:" "$ENVELOPE" 2>/dev/null | head -1 \
    | sed -e 's/^[[:space:]]*type:[[:space:]]*//' -e 's/["'\'']//g' -e 's/[[:space:]]*$//')
[ -n "$P_TYPE" ] || P_TYPE="unknown"

MSG_TYPE="pickup-$P_TYPE"
TOPIC="framework:pickup"

# Try channel.post path first (T-1160 — structured, signed, drift-tolerant Tier-A)
# T-1445: probe for --ensure-topic support (T-1443+). When the flag is
# available, idempotent topic auto-create heals across hub-restart topic
# loss (G-051). When absent (older binaries), empty flag preserves
# pre-T-1445 behavior.
ENSURE_TOPIC_FLAG=""
if termlink channel post --help 2>/dev/null | grep -q -- '--ensure-topic'; then
    ENSURE_TOPIC_FLAG="--ensure-topic"
fi

if termlink channel post --help >/dev/null 2>&1; then
    if termlink channel post "$TOPIC" $ENSURE_TOPIC_FLAG --msg-type "$MSG_TYPE" --payload-from-file "$ENVELOPE" \
            >/dev/null 2>&1 \
       || termlink channel post "$TOPIC" $ENSURE_TOPIC_FLAG --msg-type "$MSG_TYPE" --payload "$(cat "$ENVELOPE")" \
            >/dev/null 2>&1; then
        _log "posted via=channel.post topic=$TOPIC msg_type=$MSG_TYPE sha=$SHA"
        : > "$DEDUP_DIR/$SHA"
        exit 0
    fi
    # T-1814: channel.post failed. Do NOT fall back to event.broadcast — that
    # legacy primitive is being retired (T-1166) and the fallback was the lone
    # live emitter resetting the cut's clean-window gate. The bridge is a
    # non-fatal enhancement (T-1214), so a channel.post failure degrades to a
    # logged no-op. Run an --ensure-topic-capable binary (T-1443+) to auto-heal
    # the topic-loss case this fallback used to cover.
    _log "channel.post-failed envelope=$BASENAME — bus mirror skipped (event.broadcast fallback removed, T-1166/T-1814)"
    exit 0
fi

_log "skip-no-channel-post envelope=$BASENAME — channel.post unavailable (pre-T-1160 binary); bus mirror skipped"
exit 0
