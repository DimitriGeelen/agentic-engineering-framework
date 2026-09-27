#!/usr/bin/env bash
# T-1827 — enumerate conversations on a topic.
#
# Sibling of agent-conversation-status.sh (T-1826). Where status answers
# "how is cid-X doing?", list answers "what cids are alive on this topic?"
#
# Closes the orchestration gap for autonomous a2a: an agent supervising N
# concurrent doorbell+mail threads can call this verb to enumerate its own
# active set (and any abandoned/stalled ones it should clean up).
#
# Read-only. Composes `channel subscribe --json` + jq. Envelopes without
# metadata.conversation_id are skipped by default (focus on doorbell+mail
# pattern) but can be aggregated under a sentinel `(no-cid)` row via
# --include-no-cid for cross-pattern surveys.
set -euo pipefail

TERMLINK="${TERMLINK_BIN:-termlink}"

die() { echo "agent-conversation-list: $*" >&2; exit 2; }

usage() {
    cat <<'EOF'
Usage: agent-conversation-list.sh --topic <T>
                                  [--hub <addr>] [--limit <N>] [--json]
                                  [--include-no-cid] [--sort <field>]

Required:
  --topic <T>           channel topic to scan

Optional:
  --hub <addr>          target hub (default: local; e.g. 192.168.10.122:9100)
  --limit <N>           max envelopes per scan (default: 500, max 1000)
  --include-no-cid      include a sentinel row for envelopes without a cid
  --json                emit one JSON object instead of text
  --sort <field>        sort order — one of:
                          last_activity (default, descending — most recent first)
                          turn_count    (descending)
                          cid           (ascending, lexicographic)

Text output:
  table — cid | turns | receipts | senders | last_activity

JSON output:
  {ok, topic, conversation_count, conversations: [
       {conversation_id, turn_count, receipt_count, sender_count,
        senders: [...], first_activity, last_activity}
   ],
   summary: {total_envelopes_scanned, with_cid, without_cid}}

Exit: 0 ok | 2 usage/precondition | 3 subscribe failed
EOF
}

topic="" hub="" limit="500" include_no_cid=0 json=0 sort_field="last_activity"

while [ $# -gt 0 ]; do
    case "$1" in
        --topic)           topic="${2:-}"; shift 2 ;;
        --hub)             hub="${2:-}"; shift 2 ;;
        --limit)           limit="${2:-}"; shift 2 ;;
        --include-no-cid)  include_no_cid=1; shift ;;
        --json)            json=1; shift ;;
        --sort)            sort_field="${2:-}"; shift 2 ;;
        -h|--help)         usage; exit 0 ;;
        *)                 die "unknown arg: $1 (try --help)" ;;
    esac
done

[ -n "$topic" ] || { usage >&2; die "missing --topic"; }
case "$sort_field" in
    last_activity|turn_count|cid) ;;
    *) die "invalid --sort: $sort_field (must be last_activity | turn_count | cid)" ;;
esac

# Build subscribe args.
sub_args=("$topic" --json --limit "$limit")
if [ -n "$hub" ]; then
    sub_args+=(--hub "$hub")
fi

if ! raw="$("$TERMLINK" channel subscribe "${sub_args[@]}" 2>/dev/null)"; then
    echo "agent-conversation-list: channel subscribe failed for topic=$topic" >&2
    exit 3
fi

# Group by conversation_id. Envelopes without cid are either skipped (default)
# or aggregated under "(no-cid)" sentinel (when --include-no-cid).
summary="$(printf '%s' "$raw" | jq -n -c \
    --arg topic "$topic" \
    --arg sort_field "$sort_field" \
    --argjson include_no_cid "$include_no_cid" \
    '
    [inputs] as $all
    | ($all | length) as $total
    | ($all | map(select(.metadata.conversation_id != null))) as $with_cid
    | ($all | map(select(.metadata.conversation_id == null))) as $without_cid

    # Bucket the cid-bearing envelopes by cid.
    | ($with_cid
        | group_by(.metadata.conversation_id)
        | map({
            conversation_id: .[0].metadata.conversation_id,
            envelopes: .
          })
      ) as $cid_buckets

    # Optionally add a sentinel for cid-less envelopes.
    | (if $include_no_cid == 1 and ($without_cid | length) > 0 then
         $cid_buckets + [{conversation_id: "(no-cid)", envelopes: $without_cid}]
       else
         $cid_buckets
       end) as $all_buckets

    # Roll up per-bucket.
    # T-1855 / PL-191 — sender identity is multi-source on shared hosts.
    # Priority: .metadata.agent_id // .metadata._from // .sender_id.
    # T-1693 forward-compat: turn/receipt envelopes do not carry agent_id
    # today (deferred); chain falls through to .sender_id so this is a
    # zero-regression change that auto-corrects when producers gain
    # identity. Cross-ref: fleet-adoption-snapshot.sh, agent-chat-arc-recent.sh.
    | ($all_buckets | map({
        conversation_id: .conversation_id,
        turn_count: (.envelopes | map(select(.msg_type == "turn")) | length),
        receipt_count: (.envelopes | map(select(.msg_type == "receipt")) | length),
        senders: (.envelopes | map(.metadata.agent_id // .metadata._from // .sender_id // "") | unique),
        sender_count: (.envelopes | map(.metadata.agent_id // .metadata._from // .sender_id // "") | unique | length),
        first_activity_ms: (.envelopes | map(.ts) | min // 0),
        last_activity_ms: (.envelopes | map(.ts) | max // 0)
      })) as $rolled

    # Format timestamps.
    | ($rolled | map(. + {
        first_activity: (if .first_activity_ms > 0
            then (.first_activity_ms / 1000 | strftime("%Y-%m-%dT%H:%M:%SZ"))
            else null end),
        last_activity: (if .last_activity_ms > 0
            then (.last_activity_ms / 1000 | strftime("%Y-%m-%dT%H:%M:%SZ"))
            else null end)
      } | del(.first_activity_ms, .last_activity_ms))) as $formatted

    # Sort.
    | (if $sort_field == "last_activity" then
         ($formatted | sort_by(.last_activity) | reverse)
       elif $sort_field == "turn_count" then
         ($formatted | sort_by(.turn_count) | reverse)
       elif $sort_field == "cid" then
         ($formatted | sort_by(.conversation_id))
       else $formatted end) as $sorted

    | {
        ok: true,
        topic: $topic,
        conversation_count: ($sorted | length),
        conversations: $sorted,
        summary: {
            total_envelopes_scanned: $total,
            with_cid: ($with_cid | length),
            without_cid: ($without_cid | length)
        }
    }
    ')"

if [ "$json" -eq 1 ]; then
    printf '%s\n' "$summary"
    exit 0
fi

# Text mode — fixed-width-ish table.
{
    printf 'topic:               %s\n' "$topic"
    cc="$(printf '%s' "$summary" | jq -r '.conversation_count')"
    scanned="$(printf '%s' "$summary" | jq -r '.summary.total_envelopes_scanned')"
    with_cid="$(printf '%s' "$summary" | jq -r '.summary.with_cid')"
    without_cid="$(printf '%s' "$summary" | jq -r '.summary.without_cid')"
    printf 'conversations:       %s\n' "$cc"
    printf 'envelopes scanned:   %s (with_cid=%s, without_cid=%s)\n' \
        "$scanned" "$with_cid" "$without_cid"
    printf 'sort:                %s\n' "$sort_field"
    printf '\n'

    if [ "$cc" -gt 0 ]; then
        printf '%-32s %6s %8s %7s  %s\n' "cid" "turns" "receipts" "senders" "last_activity"
        printf '%-32s %6s %8s %7s  %s\n' "$(printf '%.0s-' {1..32})" "-----" "--------" "-------" "-------------------"
        printf '%s' "$summary" | jq -r '
            .conversations[] |
            [
              .conversation_id,
              (.turn_count|tostring),
              (.receipt_count|tostring),
              (.sender_count|tostring),
              (.last_activity // "—")
            ] | @tsv' | while IFS=$'\t' read -r c t r s la; do
                # Truncate cid to 32 if longer.
                if [ "${#c}" -gt 32 ]; then
                    c="${c:0:29}..."
                fi
                printf '%-32s %6s %8s %7s  %s\n' "$c" "$t" "$r" "$s" "$la"
            done
    fi
} | cat
