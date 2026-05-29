#!/usr/bin/env bash
# T-1805 — pickup-and-respond ritual: the receiver's mechanical ack (T-1800 build #2).
#
# Counterpart to scripts/agent-send.sh (T-1804). When a listener is woken by an
# injected doorbell (/check-arc) and finds an unread turn, this verb closes the
# "respond" half of the doorbell+mail loop — deterministically, with no protocol
# changes, composing only existing termlink primitives:
#
#   1. receipt : channel post <dm-topic> --msg-type receipt --metadata
#                conversation_id=<cid> --metadata up_to=<offset>
#                  -> the EXACT shape agent-send.sh polls for, so the sender
#                     learns DELIVERED (closes the PL-011 "ok != delivered" gap).
#   2. reply   : (optional, --reply) channel post <dm-topic> --msg-type turn
#                --payload <text> --metadata conversation_id=<cid>
#                  -> the actual answer, threaded on the same conversation.
#
# The receipt is the load-bearing step; the reply is the content. A woken agent
# iterates this once per unread conversation (the /check-arc respond-mode section
# drives the iteration + composes reply text); this script handles one cid.
set -euo pipefail

TERMLINK="${TERMLINK_BIN:-termlink}"

die() { echo "agent-respond: $*" >&2; exit 2; }

usage() {
    cat <<'EOF'
Usage: agent-respond.sh (--topic <dm-topic> | --peer-fp <fp>)
                        --conversation-id <id>
                        [--reply <text>] [--up-to <offset>]

Required:
  --conversation-id <id>  the thread to ack (must match the sender's cid)
  one of:
    --topic <dm-topic>    post the receipt to this topic (e.g. dm:<a>:<b>)
    --peer-fp <fp>        compute dm:<sorted self,peer> from `whoami` + this fp

Optional:
  --reply <text>          also post a turn (the answer) on the same conversation
  --up-to <offset>        receipt's up_to metadata (default: highest offset seen
                          for this cid on the topic, else 0)

Exit: 0 acked (receipt posted) | 2 usage/precondition
EOF
}

topic="" peer_fp="" cid="" reply="" up_to=""

while [ $# -gt 0 ]; do
    case "$1" in
        --topic)           topic="${2:-}"; shift 2 ;;
        --peer-fp)         peer_fp="${2:-}"; shift 2 ;;
        --conversation-id) cid="${2:-}"; shift 2 ;;
        --reply)           reply="${2:-}"; shift 2 ;;
        --up-to)           up_to="${2:-}"; shift 2 ;;
        -h|--help)         usage; exit 0 ;;
        *)                 die "unknown arg: $1 (try --help)" ;;
    esac
done

[ -n "$cid" ] || die "missing --conversation-id"

# Resolve the destination topic (mirror agent-send.sh dm_topic semantics).
if [ -n "$topic" ]; then
    :
elif [ -n "$peer_fp" ]; then
    self_fp="$("$TERMLINK" whoami --json 2>/dev/null | jq -r '.session.identity_fingerprint // empty')"
    [ -n "$self_fp" ] || die "could not resolve own identity_fingerprint (run inside a termlink session, or pass --topic)"
    # Mirror Rust dm_topic(): lexicographic sort, my_id <= peer.
    if [[ "$self_fp" < "$peer_fp" || "$self_fp" == "$peer_fp" ]]; then
        topic="dm:${self_fp}:${peer_fp}"
    else
        topic="dm:${peer_fp}:${self_fp}"
    fi
else
    die "need --topic or --peer-fp"
fi

# Default up_to to the highest offset observed for this conversation.
if [ -z "$up_to" ]; then
    up_to="$( { "$TERMLINK" channel subscribe "$topic" --conversation-id "$cid" \
                    --cursor 0 --limit 1000 --json 2>/dev/null \
                | jq -s '[ .[].offset ] | (max // 0)' ; } || true )"
    [[ "$up_to" =~ ^[0-9]+$ ]] || up_to=0
fi

# 1. Post the receipt (the load-bearing ack agent-send.sh waits for).
"$TERMLINK" channel post "$topic" --msg-type receipt \
    --metadata conversation_id="$cid" --metadata up_to="$up_to" \
    --ensure-topic --json >/dev/null \
    || die "receipt post failed for topic '$topic'"
echo "agent-respond: receipt posted to '$topic' (cid=$cid, up_to=$up_to)"

# 2. Optionally post the reply turn (the content).
if [ -n "$reply" ]; then
    reply_json="$("$TERMLINK" channel post "$topic" --msg-type turn --payload "$reply" \
                    --metadata conversation_id="$cid" --ensure-topic --json)" \
        || die "reply post failed for topic '$topic'"
    reply_offset="$(printf '%s' "$reply_json" | jq -r '.delivered.offset // empty')"
    echo "agent-respond: reply posted to '$topic' (cid=$cid, offset=${reply_offset:-?})"
fi

exit 0
