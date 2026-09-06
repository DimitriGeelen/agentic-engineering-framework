#!/usr/bin/env bats
# T-3286 — agent-chat producers must stamp metadata.agent_id.
#
# WHAT IS UNDER TEST. Three producer sites (agent-send.sh turn post,
# agent-respond.sh receipt post + reply post) used to emit only
# conversation_id. On a shared host every co-resident agent signs with the
# same host key, so a reader keying on .sender_id collapses many agents to
# one correspondent. The fix stamps metadata.agent_id from ONE shared
# resolver (agent-identity.sh, instance grain per T-3287 D1) with an ordered
# chain: FW_AGENT_ID env override → own termlink session identity →
# project+PID fallback. It must NOT read host-shared listener state.
#
# HERMETIC. The transport is a stub: `channel post` records its argv as a
# JSON envelope to posts.jsonl, `channel subscribe` replays stream.ndjson,
# `whoami` serves whoami.json when present. No live hub, no live thread.
#
# THE A3 LEGS ARE A CONTROL SET. Distinct agent_id → 2 correspondents and
# same agent_id → 1 prove the reader's tier-1 (.metadata.agent_id) path
# separates on the stamp; the agent_id-ABSENT leg pins the pre-fix collapse
# (falls to .sender_id → 1 correspondent for 2 real agents), so the pair
# proves the stamp is WHY they now separate, not some other change.

setup() {
    REPO="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    SCRIPTS="$REPO/lib/templates/scripts"
    SB="$BATS_TEST_TMPDIR/sandbox"
    mkdir -p "$SB/stub" "$SB/proj-x" "$SB/home/.termlink"
    export T3286_SB="$SB"

    POSTS="$SB/posts.jsonl"
    STREAM="$SB/stream.ndjson"
    : > "$POSTS"

    # Fixture assertions, not spot-checks (T-3254 convention).
    [ "$SB" != "$REPO" ]
    [ -f "$SCRIPTS/agent-send.sh" ]
    [ -f "$SCRIPTS/agent-respond.sh" ]
    [ -f "$SCRIPTS/agent-identity.sh" ]
    [ -f "$SCRIPTS/agent-conversation-status.sh" ]

    # A host-shared listener state naming a DIFFERENT agent. A2's negative
    # requirement: the resolver must never surface this name for a sender.
    printf '{"agent_id": "other-listener-agent", "pid": 1}\n' \
        > "$SB/home/.termlink/be-reachable.state"
    export HOME="$SB/home"
    export BE_REACHABLE_STATE="$SB/home/.termlink/be-reachable.state"

    # The env override tier must be under TEST control, never inherited.
    unset FW_AGENT_ID

    _write_stub
    export TERMLINK_BIN="$SB/stub/termlink"

    # A receipt with a high up_to watermark so agent-send.sh's delivery wait
    # is satisfied on the first subscribe (turn offsets start at 1).
    printf '%s\n' \
        '{"msg_type":"receipt","metadata":{"conversation_id":"cid-t3286","up_to":"999"},"offset":42,"sender_id":"peer-fp","ts":1757000000000}' \
        > "$STREAM"
}

# Quoted heredoc: the stub reads everything through $T3286_SB at runtime.
_write_stub() {
    cat > "$SB/stub/termlink" <<'STUB'
#!/usr/bin/env bash
SB="${T3286_SB:?}"
verb="$1"; shift
case "$verb" in
  whoami)
    [ -f "$SB/whoami.json" ] && { cat "$SB/whoami.json"; exit 0; }
    exit 1 ;;
  inject) exit 0 ;;
  channel)
    sub="$1"; shift
    case "$sub" in
      post)
        topic="$1"; shift
        msg_type=""; payload=""; meta="{}"
        while [ $# -gt 0 ]; do
          case "$1" in
            --msg-type) msg_type="$2"; shift 2 ;;
            --payload)  payload="$2"; shift 2 ;;
            --metadata)
              k="${2%%=*}"; v="${2#*=}"
              meta="$(printf '%s' "$meta" | jq -c --arg k "$k" --arg v "$v" '. + {($k): $v}')"
              shift 2 ;;
            *) shift ;;
          esac
        done
        n=$(cat "$SB/offset" 2>/dev/null || echo 0); n=$((n+1)); echo "$n" > "$SB/offset"
        jq -nc --arg topic "$topic" --arg mt "$msg_type" --arg p "$payload" \
               --argjson meta "$meta" --argjson off "$n" \
               '{topic:$topic, msg_type:$mt, payload:$p, metadata:$meta, offset:$off}' \
               >> "$SB/posts.jsonl"
        printf '{"delivered":{"offset":%s}}\n' "$n"
        exit 0 ;;
      subscribe)
        [ -f "$SB/stream.ndjson" ] && cat "$SB/stream.ndjson"
        exit 0 ;;
    esac
    exit 0 ;;
  *) exit 0 ;;
esac
STUB
    chmod +x "$SB/stub/termlink"
}

_send() {
    bash "$SCRIPTS/agent-send.sh" --to-session peer --topic dm:a:b \
        --conversation-id cid-t3286 --timeout 2 --max-rings 1 "$@"
}

_respond() {
    bash "$SCRIPTS/agent-respond.sh" --topic dm:a:b \
        --conversation-id cid-t3286 --up-to 1 "$@"
}

# Rebuild the reader's stream from the envelopes the producers ACTUALLY
# emitted, with the shared-host sender_id every co-resident agent gets —
# so the reader legs are end-to-end from captured producer output.
_stream_from_posts() {
    jq -c '{msg_type, offset, metadata, sender_id: "shared-host-fp", ts: 1757000000000}' \
        "$POSTS" > "$STREAM"
}

_status_json() {
    bash "$SCRIPTS/agent-conversation-status.sh" \
        --topic dm:a:b --conversation-id cid-t3286 --json
}

@test "A1: agent-send turn post carries agent_id alongside conversation_id" {
    FW_AGENT_ID=sender-alpha run _send --message "hello"
    [ "$status" -eq 0 ]
    turn="$(jq -c 'select(.msg_type == "turn")' "$POSTS")"
    [ -n "$turn" ]
    [ "$(printf '%s' "$turn" | jq -r '.metadata.agent_id')" = "sender-alpha" ]
    [ "$(printf '%s' "$turn" | jq -r '.metadata.conversation_id')" = "cid-t3286" ]
}

@test "A1: agent-respond receipt AND reply posts carry agent_id" {
    FW_AGENT_ID=sender-beta run _respond --reply "the answer"
    [ "$status" -eq 0 ]
    [ "$(jq -s 'length' "$POSTS")" -eq 2 ]
    receipt="$(jq -c 'select(.msg_type == "receipt")' "$POSTS")"
    reply="$(jq -c 'select(.msg_type == "turn")' "$POSTS")"
    [ "$(printf '%s' "$receipt" | jq -r '.metadata.agent_id')" = "sender-beta" ]
    [ "$(printf '%s' "$receipt" | jq -r '.metadata.up_to')" = "1" ]
    [ "$(printf '%s' "$reply"   | jq -r '.metadata.agent_id')" = "sender-beta" ]
}

@test "A2 tier 1: FW_AGENT_ID override wins over a live session identity" {
    printf '%s\n' '{"ok":true,"session":{"display_name":"worker-a","id":"tl-aaa111","identity_fingerprint":"shared-host-fp"}}' \
        > "$SB/whoami.json"
    FW_AGENT_ID=explicit-me run _respond
    [ "$status" -eq 0 ]
    [ "$(jq -r '.metadata.agent_id' "$POSTS")" = "explicit-me" ]
}

@test "A2 tier 2: no override resolves the sender's OWN session identity, not the fingerprint" {
    printf '%s\n' '{"ok":true,"session":{"display_name":"worker-a","id":"tl-aaa111","identity_fingerprint":"shared-host-fp"}}' \
        > "$SB/whoami.json"
    run _respond
    [ "$status" -eq 0 ]
    stamped="$(jq -r '.metadata.agent_id' "$POSTS")"
    [ "$stamped" = "worker-a@tl-aaa111" ]
    # The host-shared fingerprint must NOT be the identity — it is the collapse.
    [ "$stamped" != "shared-host-fp" ]
}

@test "A2 tier 3: no override, no session -> project+PID; NEVER the host-shared listener's name" {
    # whoami.json absent: stub whoami exits 1, chain falls to the derived tier.
    PROJECT_ROOT="$SB/proj-x" run _respond
    [ "$status" -eq 0 ]
    stamped="$(jq -r '.metadata.agent_id' "$POSTS")"
    [[ "$stamped" =~ ^proj-x-pid[0-9]+$ ]]
    # A2's negative requirement: be-reachable.state names other-listener-agent
    # (see setup); a resolver that read host-shared listener state would stamp
    # every sender with that one name — the same collapse wearing a name.
    [[ "$stamped" != *"other-listener-agent"* ]]
}

@test "A3: DISTINCT agent_id envelopes resolve to TWO correspondents (tier-1 reader path)" {
    FW_AGENT_ID=agent-one run _send --message "ping"
    [ "$status" -eq 0 ]
    FW_AGENT_ID=agent-two run _respond --reply "pong"
    [ "$status" -eq 0 ]
    _stream_from_posts
    run _status_json
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | jq -r '.summary.sender_count')" -eq 2 ]
    printf '%s' "$output" | jq -e '.senders | index("agent-one")' >/dev/null
    printf '%s' "$output" | jq -e '.senders | index("agent-two")' >/dev/null
}

@test "A3: SAME agent_id envelopes resolve to ONE correspondent" {
    FW_AGENT_ID=agent-same run _send --message "ping"
    [ "$status" -eq 0 ]
    FW_AGENT_ID=agent-same run _respond --reply "pong"
    [ "$status" -eq 0 ]
    _stream_from_posts
    run _status_json
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | jq -r '.summary.sender_count')" -eq 1 ]
    [ "$(printf '%s' "$output" | jq -r '.senders[0]')" = "agent-same" ]
}

@test "A3 CONTROL: agent_id ABSENT falls to sender_id — two real agents collapse to one (pre-fix shape)" {
    # Hand-built envelopes: two turns from two DIFFERENT co-resident agents,
    # no metadata.agent_id, identical host-key sender_id. This is what the
    # producers emitted before T-3286; the reader cannot tell them apart.
    printf '%s\n%s\n' \
        '{"msg_type":"turn","offset":1,"metadata":{"conversation_id":"cid-t3286"},"sender_id":"shared-host-fp","ts":1757000000000}' \
        '{"msg_type":"turn","offset":2,"metadata":{"conversation_id":"cid-t3286"},"sender_id":"shared-host-fp","ts":1757000001000}' \
        > "$STREAM"
    run _status_json
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | jq -r '.summary.sender_count')" -eq 1 ]
    [ "$(printf '%s' "$output" | jq -r '.senders[0]')" = "shared-host-fp" ]
}

@test "edited producers and the shared resolver parse (bash -n)" {
    bash -n "$SCRIPTS/agent-send.sh"
    bash -n "$SCRIPTS/agent-respond.sh"
    bash -n "$SCRIPTS/agent-identity.sh"
}
