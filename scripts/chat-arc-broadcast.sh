#!/usr/bin/env bash
# T-1856 — Cross-hub broadcast helper for agent-chat-arc.
#
# G-060 mitigation: agent-chat-arc does NOT federate
# (see docs/operations/channel-topic-semantics.md). Cross-hub broadcast
# requires explicit `channel post --hub <addr>` per hub. This script
# wraps that loop with the PL-189 timeout invariant and automatic
# metadata.agent_id injection so a single operator command reaches the
# fleet with correct attribution.
#
# Sender resolution (priority order):
#   1. --from <id> flag
#   2. $TERMLINK_AGENT_ID env
#   3. jq -r .agent_id ~/.termlink/be-reachable.state (auto-detect from /be-reachable)
#   4. exit 2 with hint
#
# Exit codes:
#   0 — every reachable hub delivered
#   1 — at least one hub failed (drift, timeout, or post-side error)
#   2 — tooling/usage error (missing payload, missing sender, jq/termlink missing)
#
# Usage:
#   chat-arc-broadcast.sh --payload "TEXT" [--from ID] [--hubs-file P]
#                          [--timeout-secs N] [--json]
set -u

TERMLINK="${TERMLINK_BIN:-termlink}"
HUBS_FILE="${HOME}/.termlink/hubs.toml"
BE_REACHABLE_STATE="${HOME}/.termlink/be-reachable.state"
PER_HUB_TIMEOUT=8   # PL-189 — same per-call bound as the discovery verbs
FORMAT=human
PAYLOAD=""
FROM=""

die() {
    if [ "$FORMAT" = json ]; then
        printf '{"ok":false,"error":"%s"}\n' "$1"
    else
        echo "chat-arc-broadcast: $1" >&2
    fi
    exit 2
}

usage() {
    sed -n '2,28p' "$0"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --payload)        PAYLOAD="${2:-}"; shift 2 ;;
        --from)           FROM="${2:-}"; shift 2 ;;
        --hubs-file)      HUBS_FILE="${2:-}"; shift 2 ;;
        --timeout-secs)   PER_HUB_TIMEOUT="${2:-}"; shift 2 ;;
        --json)           FORMAT=json; shift ;;
        -h|--help)        usage; exit 0 ;;
        *)                echo "unknown arg: $1 (try --help)" >&2; exit 2 ;;
    esac
done

[ -n "$PAYLOAD" ] || die "missing --payload"
command -v jq >/dev/null 2>&1 || die "jq not in PATH"
command -v "$TERMLINK" >/dev/null 2>&1 || die "termlink binary not in PATH (set TERMLINK_BIN)"
[ -f "$HUBS_FILE" ] || die "hubs file not found: $HUBS_FILE"

# Sender resolution chain.
if [ -z "$FROM" ]; then
    FROM="${TERMLINK_AGENT_ID:-}"
fi
if [ -z "$FROM" ] && [ -f "$BE_REACHABLE_STATE" ]; then
    FROM="$(jq -r '.agent_id // empty' "$BE_REACHABLE_STATE" 2>/dev/null || true)"
fi
[ -n "$FROM" ] || die "sender unresolved — pass --from <id>, or export TERMLINK_AGENT_ID, or run /be-reachable first"

# Validate timeout is a positive integer to prevent injection via --timeout-secs.
case "$PER_HUB_TIMEOUT" in
    ''|*[!0-9]*) die "invalid --timeout-secs: $PER_HUB_TIMEOUT" ;;
esac

# Build TIMEOUT_CMD; degrade gracefully if `timeout` is missing.
if command -v timeout >/dev/null 2>&1; then
    TIMEOUT_CMD="timeout $PER_HUB_TIMEOUT"
else
    TIMEOUT_CMD=""
fi

# Extract unique hub addresses from hubs.toml. Uses the same minimal TOML
# parsing as fleet-adoption-snapshot.sh / agent-chat-arc-recent.sh — only
# top-level `address = "..."` lines under `[hubs.NAME]` sections.
addrs="$(awk '
    /^\[hubs\.[^]]+\]/ { in_hub=1; next }
    /^\[/             { in_hub=0; next }
    in_hub && /^address[[:space:]]*=/ {
        gsub(/.*=[[:space:]]*"/, "")
        gsub(/".*$/, "")
        print
    }
' "$HUBS_FILE" | sort -u)"

[ -n "$addrs" ] || die "no hub addresses parsed from $HUBS_FILE"

attempted=0
delivered=0
failed=0
results_payload=""

# Per-hub post loop. Each call internally bounded by PER_HUB_TIMEOUT;
# failures append to the result envelope but don't abort the loop.
while IFS= read -r addr; do
    [ -n "$addr" ] || continue
    attempted=$((attempted + 1))

    out="$($TIMEOUT_CMD "$TERMLINK" channel post agent-chat-arc \
        --hub "$addr" \
        --msg-type chat \
        --payload "$PAYLOAD" \
        --metadata agent_id="$FROM" \
        --metadata _from="$FROM" \
        --ensure-topic --json 2>&1 || true)"

    offset="$(printf '%s' "$out" | jq -r '.delivered.offset // empty' 2>/dev/null || true)"
    if [ -n "$offset" ]; then
        delivered=$((delivered + 1))
        row="$(jq -n -c --arg h "$addr" --argjson o "$offset" \
            '{hub:$h, ok:true, offset:$o, error:null}')"
    else
        failed=$((failed + 1))
        # First line of stderr is the most useful for diagnosis.
        err="$(printf '%s' "$out" | head -1 | tr -d '\n' | jq -R -s -c '.')"
        row="$(jq -n -c --arg h "$addr" --argjson e "$err" \
            '{hub:$h, ok:false, offset:null, error:$e}')"
    fi

    if [ -z "$results_payload" ]; then
        results_payload="$row"
    else
        results_payload="$results_payload"$'\n'"$row"
    fi

    if [ "$FORMAT" = human ]; then
        if [ -n "$offset" ]; then
            printf '  %-28s offset=%s\n' "$addr" "$offset"
        else
            printf '  %-28s FAILED: %s\n' "$addr" \
                "$(printf '%s' "$out" | head -1)"
        fi
    fi
done <<< "$addrs"

overall_ok=true
[ "$failed" -gt 0 ] && overall_ok=false

if [ "$FORMAT" = json ]; then
    results_arr="$(printf '%s\n' "$results_payload" | jq -s -c '.')"
    jq -n -c \
        --argjson ok "$overall_ok" \
        --argjson att "$attempted" \
        --argjson del "$delivered" \
        --argjson fail "$failed" \
        --arg from "$FROM" \
        --argjson results "$results_arr" \
        '{ok:$ok, hubs_attempted:$att, hubs_delivered:$del, hubs_failed:$fail, sender:$from, results:$results}'
else
    echo
    echo "chat-arc-broadcast: $delivered/$attempted delivered, $failed failed (sender=$FROM)"
fi

[ "$overall_ok" = true ] && exit 0 || exit 1
