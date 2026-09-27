#!/usr/bin/env bash
# T-1804 — deterministic doorbell+mail send verb (T-1800 build #1).
#
# Composes EXISTING termlink primitives (no protocol changes) into one atomic
# send so the SENDER always learns delivered-or-failed — closing the PL-011
# "ok:true means hub-accepted, NOT delivered" gap for conversational turns:
#
#   1. mail     : channel post <dm-topic> --msg-type turn  (the turn content)
#   2. doorbell : inject <peer-session> "/check-arc"        (wake the listener)
#   3. receipt  : poll the dm-topic (filtered by conversation_id) for a
#                 msg_type=receipt envelope (the receiver's ack)
#   4. re-ring  : if no receipt within the per-attempt timeout, ring again,
#                 up to --max-rings; then exit non-zero (NOT delivered).
#
# The turn is posted once up front; only the doorbell is repeated. An inject
# failure (e.g. listener session missing/renamed) is non-fatal — the mail is
# already posted and the receipt wait continues.
set -euo pipefail

TERMLINK="${TERMLINK_BIN:-termlink}"

die() { echo "agent-send: $*" >&2; exit 2; }

usage() {
    cat <<'EOF'
Usage: agent-send.sh --to-session <name> (--topic <dm-topic> | --peer-fp <fp>)
                     --message <text>
                     [--conversation-id <id>] [--timeout <secs>]
                     [--max-rings <n>] [--doorbell-text <text>]
                     [--await-reply <secs>]
       agent-send.sh --to <agent-id> --message <text> [other flags] [--dry-run]

Required:
  --message <text>      the turn content (the "mail")
  exactly one routing form:
    --to <agent-id>     auto-discover: resolve --to-session and --topic by
                        looking up agent-id in agent-presence (T-1834).
                        Requires listener to declare pty_session and a
                        dm:* listen_topic.
    --to-session <name> + (--topic <dm-topic> | --peer-fp <fp>)
                        explicit routing (the pre-T-1834 form).

Optional:
  --conversation-id <id>  thread id (default: cid-<epoch>-<rand>)
  --timeout <secs>        seconds to wait for a receipt per ring (default: 10)
  --max-rings <n>         max doorbell attempts (default: 3)
  --doorbell-text <text>  what to inject to wake the listener
                          (default: "/check-arc respond" — signals respond mode)
  --await-reply <secs>    after delivery, wait up to <secs> for the peer's reply
                          turn (first msg_type=turn with offset > the posted turn
                          on this conversation_id) and print it. Turns
                          send+confirm into a full request->response round-trip.
  --dry-run               with --to, print RESOLVED line and exit 0 without
                          posting or injecting (test/preview seam).

Exit: 0 delivered (and reply printed if --await-reply, or dry-run RESOLVED)
      | 2 usage/precondition (incl. auto-discover resolution failures)
      | 3 not acked after N rings | 4 delivered but no reply within --await-reply
EOF
}

to_session="" topic="" peer_fp="" message="" cid="" await_reply=""
to_agent_id="" dry_run=0
# Default doorbell SIGNALS respond mode (T-1809): a bare `/check-arc` wakes the
# listener in read-only browse mode and it never acks; `/check-arc respond` tells
# it to enter respond mode and post a receipt+reply. Override with --doorbell-text.
timeout=10 max_rings=3 doorbell_text="/check-arc respond"

while [ $# -gt 0 ]; do
    case "$1" in
        --to)             to_agent_id="${2:-}"; shift 2 ;;
        --to-session)     to_session="${2:-}"; shift 2 ;;
        --topic)          topic="${2:-}"; shift 2 ;;
        --peer-fp)        peer_fp="${2:-}"; shift 2 ;;
        --message)        message="${2:-}"; shift 2 ;;
        --conversation-id) cid="${2:-}"; shift 2 ;;
        --timeout)        timeout="${2:-}"; shift 2 ;;
        --max-rings)      max_rings="${2:-}"; shift 2 ;;
        --doorbell-text)  doorbell_text="${2:-}"; shift 2 ;;
        --await-reply)    await_reply="${2:-}"; shift 2 ;;
        --dry-run)        dry_run=1; shift ;;
        -h|--help)        usage; exit 0 ;;
        *)                die "unknown arg: $1 (try --help)" ;;
    esac
done

[ -n "$message" ]    || die "missing --message"

# T-1834: --to <agent-id> auto-discover. Mutually exclusive with explicit
# routing flags (--to-session/--topic/--peer-fp). If --to is set, resolve
# both to_session and topic by reading agent-presence via agent-listeners.sh.
if [ -n "$to_agent_id" ]; then
    if [ -n "$to_session" ] || [ -n "$topic" ] || [ -n "$peer_fp" ]; then
        die "--to is mutex with --to-session / --topic / --peer-fp; pick one routing form"
    fi
    LISTENERS_VERB="${LISTENERS_VERB:-scripts/agent-listeners.sh}"
    [ -x "$LISTENERS_VERB" ] || die "agent-listeners verb not executable: $LISTENERS_VERB"
    resolved="$(bash "$LISTENERS_VERB" --filter-agent-id "$to_agent_id" --include-offline --json 2>/dev/null)"
    [ -n "$resolved" ] || die "agent-listeners returned no output for agent-id=$to_agent_id"
    total="$(printf '%s' "$resolved" | jq -r '.total_listeners // 0')"
    if [ "$total" = "0" ]; then
        die "no listener with agent_id=$to_agent_id (run 'agent-listeners.sh' to see who's live)"
    fi
    listener="$(printf '%s' "$resolved" | jq -c '.listeners[0]')"
    status="$(printf '%s' "$listener" | jq -r '.status')"
    if [ "$status" = "OFFLINE" ]; then
        age="$(printf '%s' "$listener" | jq -r '.age_secs')"
        die "agent $to_agent_id is OFFLINE (last heartbeat ${age}s ago)"
    fi
    resolved_session="$(printf '%s' "$listener" | jq -r '.pty_session // empty')"
    [ -n "$resolved_session" ] && [ "$resolved_session" != "null" ] \
        || die "agent $to_agent_id heartbeat does not declare pty_session — sender cannot ring the doorbell"
    listen_csv="$(printf '%s' "$listener" | jq -r '.listen_topics // empty')"
    resolved_topic=""
    IFS=',' read -ra parts <<< "$listen_csv"
    for p in "${parts[@]}"; do
        # Strip whitespace.
        t="$(echo "$p" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        if [[ "$t" == dm:* ]]; then
            resolved_topic="$t"
            break
        fi
    done
    [ -n "$resolved_topic" ] || die "agent $to_agent_id has no dm:* listen_topic — sender cannot infer destination"
    to_session="$resolved_session"
    topic="$resolved_topic"
    if [ "$dry_run" -eq 1 ]; then
        echo "RESOLVED: agent_id=$to_agent_id status=$status to_session=$to_session topic=$topic"
        exit 0
    fi
elif [ "$dry_run" -eq 1 ]; then
    die "--dry-run requires --to <agent-id>"
fi

[ -n "$to_session" ] || die "missing --to-session (the doorbell target) — or use --to <agent-id> for auto-discover"
[[ "$timeout" =~ ^[0-9]+$ && "$timeout" -ge 1 ]]     || die "--timeout must be a positive integer"
[[ "$max_rings" =~ ^[0-9]+$ && "$max_rings" -ge 1 ]] || die "--max-rings must be a positive integer"
if [ -n "$await_reply" ]; then
    [[ "$await_reply" =~ ^[0-9]+$ && "$await_reply" -ge 1 ]] || die "--await-reply must be a positive integer"
fi

# Resolve the destination topic.
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

[ -n "$cid" ] || cid="cid-$(date +%s)-${RANDOM}"

# 1. Post the turn (mail) once.
post_json="$("$TERMLINK" channel post "$topic" --msg-type turn --payload "$message" \
                --metadata conversation_id="$cid" --ensure-topic --json)" \
    || die "channel post failed for topic '$topic'"
post_offset="$(printf '%s' "$post_json" | jq -r '.delivered.offset // empty')"
[ -n "$post_offset" ] || die "post returned no offset: $post_json"
echo "agent-send: posted turn to '$topic' (cid=$cid, offset=$post_offset)"

# 2. Ring the doorbell + wait for a receipt; re-ring up to the cap.
deliver_offset=""
for (( ring=1; ring<=max_rings; ring++ )); do
    echo "agent-send: ring $ring/$max_rings -> inject '$doorbell_text' into '$to_session'"
    if ! "$TERMLINK" inject "$to_session" "$doorbell_text" --enter >/dev/null 2>&1; then
        echo "agent-send: WARN ring $ring — inject into '$to_session' failed (session missing?); turn already posted, still awaiting receipt" >&2
    fi
    waited=0
    while (( waited < timeout )); do
        # Offset-aware: only a receipt that acks THIS turn counts (up_to >= the
        # offset we just posted). A stale receipt from an earlier turn on the
        # same conversation_id must NOT satisfy this wait — that was the T-1808
        # multi-turn false-DELIVERED bug.
        recv="$( { "$TERMLINK" channel subscribe "$topic" --conversation-id "$cid" \
                       --cursor 0 --limit 1000 --json 2>/dev/null \
                   | jq -s --argjson po "$post_offset" \
                       '[ .[] | select(.msg_type=="receipt")
                              | select((.metadata.up_to|tonumber? // -1) >= $po) ]
                        | (.[0].offset // empty)' ; } || true )"
        if [ -n "$recv" ] && [ "$recv" != "null" ]; then
            deliver_offset="$recv"; break
        fi
        sleep 1; waited=$((waited+1))
    done
    [ -n "$deliver_offset" ] && break
done

if [ -n "$deliver_offset" ]; then
    echo "agent-send: DELIVERED — receipt for cid=$cid at offset=$deliver_offset"
    [ -n "$await_reply" ] || exit 0

    # --await-reply: poll for the peer's reply turn — the first msg_type=turn on
    # this conversation_id with offset > the turn we posted. We posted exactly one
    # turn (at post_offset), so any later turn on the cid is the peer's reply.
    # Offset (not sender_id) is the discriminator: on a shared host all co-resident
    # agents sign with the same host key, so sender_id can't tell my turn from the
    # peer's reply (reference: shared-host-envelope-identity / T-1693).
    echo "agent-send: awaiting reply (cid=$cid, up to ${await_reply}s)"
    reply_waited=0
    while (( reply_waited < await_reply )); do
        reply_json="$( { "$TERMLINK" channel subscribe "$topic" --conversation-id "$cid" \
                            --cursor 0 --limit 1000 --json 2>/dev/null \
                        | jq -c -s --argjson po "$post_offset" \
                            '[ .[] | select(.msg_type=="turn")
                                   | select((.offset|tonumber? // -1) > $po) ]
                             | (.[0] // empty)' ; } || true )"
        if [ -n "$reply_json" ] && [ "$reply_json" != "null" ]; then
            reply_offset="$(printf '%s' "$reply_json" | jq -r '.offset // empty')"
            reply_payload="$(printf '%s' "$reply_json" | jq -r '(.payload_b64 // "") | @base64d')"
            echo "agent-send: REPLY at offset=$reply_offset:"
            printf '%s\n' "$reply_payload"
            exit 0
        fi
        sleep 1; reply_waited=$((reply_waited+1))
    done

    echo "agent-send: DELIVERED but no reply within ${await_reply}s (cid=$cid; receipt at offset=$deliver_offset)" >&2
    exit 4
fi

echo "agent-send: FAILED — no receipt for cid=$cid after $max_rings ring(s) (turn posted at offset=$post_offset; receiver never acked)" >&2
exit 3
