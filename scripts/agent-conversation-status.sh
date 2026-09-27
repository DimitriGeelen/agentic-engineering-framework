#!/usr/bin/env bash
# T-1826 — conversation_id state diagnostic.
#
# Read-only summary of a single conversation thread identified by
# `metadata.conversation_id`. Closes the observability gap in the
# doorbell+mail loop (T-1800/T-1804/T-1805): agent-send.sh polls
# receipts internally and exits status-only; agent-respond.sh posts
# receipts; nothing external can answer "where is cid-X right now?"
# for a third observer (operator or orchestrator agent supervising
# concurrent autonomous a2a threads).
#
# Composes existing first-class primitives:
#   - `channel subscribe --conversation-id <cid> --json`  (cli.rs:2319)
#   - jq + bash for the summary roll-up
# No protocol change. Empty conversation_id is a valid state (exit 0).
set -euo pipefail

TERMLINK="${TERMLINK_BIN:-termlink}"

die() { echo "agent-conversation-status: $*" >&2; exit 2; }

usage() {
    cat <<'EOF'
Usage: agent-conversation-status.sh --topic <T> --conversation-id <CID>
                                    [--hub <addr>] [--limit <N>] [--json]

Required:
  --topic <T>             channel topic to inspect (e.g. dm:<a>:<b>)
  --conversation-id <CID> thread id to filter on (metadata.conversation_id)

Optional:
  --hub <addr>            target hub (default: local; e.g. 192.168.10.122:9100)
  --limit <N>             max envelopes per scan (default: 200, max 1000)
  --json                  emit one JSON object (machine-readable) instead of text

Text output:
  topic, conversation_id, turn count + per-sender breakdown, receipt count +
  per-up_to mapping, pending turn offsets (no matching receipt), distinct
  senders, last activity (RFC3339).

JSON output (single line):
  {ok, topic, conversation_id, turns:[...], receipts:[...],
   pending_turn_offsets:[...], senders:[...], last_activity,
   summary:{turn_count, receipt_count, pending_count, sender_count}}

Exit: 0 ok (incl. empty conversation) | 2 usage/precondition | 3 subscribe failed
EOF
}

topic="" cid="" hub="" limit="200" json=0

while [ $# -gt 0 ]; do
    case "$1" in
        --topic)           topic="${2:-}"; shift 2 ;;
        --conversation-id) cid="${2:-}"; shift 2 ;;
        --hub)             hub="${2:-}"; shift 2 ;;
        --limit)           limit="${2:-}"; shift 2 ;;
        --json)            json=1; shift ;;
        -h|--help)         usage; exit 0 ;;
        *)                 die "unknown arg: $1 (try --help)" ;;
    esac
done

[ -n "$topic" ] || { usage >&2; die "missing --topic"; }
[ -n "$cid" ]   || { usage >&2; die "missing --conversation-id"; }

# Build the subscribe args (positional topic, not a flag).
sub_args=("$topic" --conversation-id "$cid" --json --limit "$limit")
if [ -n "$hub" ]; then
    sub_args+=(--hub "$hub")
fi

# Capture the NDJSON stream. If `channel subscribe` fails non-empty cid is fine —
# zero rows still parses to an empty result and we exit 0.
if ! raw="$("$TERMLINK" channel subscribe "${sub_args[@]}" 2>/dev/null)"; then
    echo "agent-conversation-status: channel subscribe failed for topic=$topic" >&2
    exit 3
fi

# Roll up: turns, receipts, senders, pending. Receipts ack up to a watermark
# (metadata.up_to >= turn.offset means that turn is delivered). Pending = turn
# offsets with no receipt watermark >= that offset.
summary="$(printf '%s' "$raw" | jq -n -c \
    --arg topic "$topic" \
    --arg cid "$cid" \
    '
    # T-1855 / PL-191 — sender identity is multi-source on shared hosts.
    # Same priority chain as fleet-adoption-snapshot.sh + agent-chat-arc-recent.sh:
    #   1. .metadata.agent_id  (explicit agent identity — /be-reachable convention)
    #   2. .metadata._from     (vendored-arc heartbeat convention, T-1438)
    #   3. .sender_id          (envelope fingerprint — collapses co-resident agents)
    # T-1693 forward-compat: agent-send/respond do not write metadata.agent_id
    # today (deferred to T-1693), so chain falls through to .sender_id; the
    # moment producers gain identity this reader auto-resolves correctly.
    [inputs] as $all
    | ($all | map(select(.msg_type == "turn") | {
        offset,
        sender: (.metadata.agent_id // .metadata._from // .sender_id // ""),
        ts
      }))
        as $turns
    | ($all | map(select(.msg_type == "receipt") | {
        offset,
        up_to: ((.metadata.up_to // "0") | tonumber? // 0),
        sender: (.metadata.agent_id // .metadata._from // .sender_id // ""),
        ts
      }))
        as $receipts
    | ([($turns + $receipts)[]?.sender] | unique) as $senders
    | (($turns + $receipts) | map(.ts) | max // 0) as $last_ts
    | ([$receipts[]?.up_to] | max // -1) as $max_up_to
    | ($turns | map(select(.offset > $max_up_to) | .offset)) as $pending
    | {
        ok: true,
        topic: $topic,
        conversation_id: $cid,
        turns: $turns,
        receipts: $receipts,
        senders: $senders,
        pending_turn_offsets: $pending,
        last_activity: (if $last_ts > 0
            then ($last_ts / 1000 | strftime("%Y-%m-%dT%H:%M:%SZ"))
            else null end),
        summary: {
            turn_count: ($turns | length),
            receipt_count: ($receipts | length),
            pending_count: ($pending | length),
            sender_count: ($senders | length)
        }
    }
    ')"

if [ "$json" -eq 1 ]; then
    printf '%s\n' "$summary"
    exit 0
fi

# Text mode — human-readable rendering.
{
    printf 'topic:           %s\n' "$topic"
    printf 'conversation_id: %s\n' "$cid"
    printf '\n'

    tc="$(printf '%s' "$summary" | jq -r '.summary.turn_count')"
    rc="$(printf '%s' "$summary" | jq -r '.summary.receipt_count')"
    pc="$(printf '%s' "$summary" | jq -r '.summary.pending_count')"
    sc="$(printf '%s' "$summary" | jq -r '.summary.sender_count')"
    last="$(printf '%s' "$summary" | jq -r '.last_activity // "—"')"

    printf 'turns:           %s\n' "$tc"
    if [ "$tc" -gt 0 ]; then
        printf '%s' "$summary" \
            | jq -r '.turns | group_by(.sender) | .[] | "  by \(.[0].sender): \(length) (offsets: \([.[].offset] | join(",")))"'
    fi

    printf 'receipts:        %s\n' "$rc"
    if [ "$rc" -gt 0 ]; then
        printf '%s' "$summary" \
            | jq -r '.receipts | .[] | "  offset=\(.offset) up_to=\(.up_to) by \(.sender)"'
    fi

    printf 'pending:         %s' "$pc"
    if [ "$pc" -gt 0 ]; then
        pending_csv="$(printf '%s' "$summary" | jq -r '.pending_turn_offsets | join(",")')"
        printf ' (offsets: %s)' "$pending_csv"
    fi
    printf '\n'

    printf 'senders:         %s\n' "$sc"
    if [ "$sc" -gt 0 ]; then
        printf '%s' "$summary" | jq -r '.senders | .[] | "  - \(.)"'
    fi

    printf 'last_activity:   %s\n' "$last"
} | cat
