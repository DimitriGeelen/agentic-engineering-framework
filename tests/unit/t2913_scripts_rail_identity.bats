#!/usr/bin/env bats
# T-2913 — in-repo scripts that post to a rail must carry the project's rail
# signing identity and the canonical from_project label, like `fw rail post`.
#
# WHAT WAS WRONG. Six producers — the messaging-toolkit scripts agent-send,
# agent-respond, chat-arc-broadcast, listener-heartbeat (lib/templates/scripts,
# copied into consumers' scripts/) and the pickup/learning bridges
# (lib/pickup-channel-bridge.sh, lib/publish-learning-to-bus.sh) — called
# `termlink channel post` bare. No TERMLINK_IDENTITY_FILE (host-signed) and no
# from_project label, i.e. none of T-2904 / T-2905.
#
# HERMETIC. termlink is a stub that records each `channel post` argv plus the
# TERMLINK_IDENTITY_FILE it was launched with; nothing reaches a hub. The
# toolkit scripts are run from a CONSUMER layout (scripts/ beside
# .agentic-framework/lib/), the way fw upgrade installs them, so the lib lookup
# is exercised rather than assumed.
#
# The control leg (C) runs the same post with the framework lib absent and
# asserts the label is missing — proving the label in (A) comes from the
# rail-identity path and not from the stub or the fixture.

setup() {
    REPO="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    SB="$BATS_TEST_TMPDIR/sb"
    PROJ="$SB/Proj_T2913"
    mkdir -p "$SB/stub" "$SB/home/.termlink" "$PROJ/scripts" \
             "$PROJ/.agentic-framework/lib" "$PROJ/.context/working"
    [ "$PROJ" != "$REPO" ]

    for f in agent-send agent-respond chat-arc-broadcast listener-heartbeat \
             agent-identity rail-post; do
        cp "$REPO/lib/templates/scripts/$f.sh" "$PROJ/scripts/"
    done
    cp "$REPO/lib/rail-identity.sh" "$REPO/lib/config.sh" \
       "$PROJ/.agentic-framework/lib/"
    printf 'RAIL_IDENTITY_FILE: .context/rail.key\n' > "$PROJ/.framework.yaml"

    POSTS="$SB/posts.jsonl"; : > "$POSTS"
    export T2913_SB="$SB"
    cat > "$SB/stub/termlink" <<'STUB'
#!/usr/bin/env bash
SB="${T2913_SB:?}"
if [ "$1 $2" = "channel post" ]; then
    shift 2
    [ "${1:-}" = "--help" ] && { echo "  --ensure-topic"; exit 0; }
    jq -nc --arg idf "${TERMLINK_IDENTITY_FILE:-}" '{args:$ARGS.positional, idfile:$idf}' \
        --args -- "$@" >> "$SB/posts.jsonl"
    printf '{"delivered":{"offset":7}}\n'
    exit 0
fi
case "$1" in
  channel)
    [ "$2" = "subscribe" ] && printf '%s\n' \
      '{"msg_type":"receipt","metadata":{"conversation_id":"cid-t2913","up_to":"999"},"offset":8}'
    exit 0 ;;
  whoami) exit 1 ;;
  *) exit 0 ;;
esac
STUB
    chmod +x "$SB/stub/termlink"

    export HOME="$SB/home"
    export PATH="$SB/stub:$PATH"
    export TERMLINK_BIN="$SB/stub/termlink"
    export PROJECT_ROOT="$PROJ"
    unset FRAMEWORK_ROOT TERMLINK_IDENTITY_FILE TERMLINK_AGENT_ID FW_RAIL_IDENTITY_FILE \
          FW_RAIL_PROJECT_LABEL FW_RAIL_IDENTITY_LIB FW_AGENT_ID
    cd "$PROJ"
}

# Every recorded post carries exactly one from_project=proj-t2913 and the
# project key as its identity file.
_assert_all_posts_governed() {
    local n
    n="$(wc -l < "$POSTS")"
    [ "$n" -ge "${1:-1}" ] || { echo "expected >= ${1:-1} posts, got $n"; cat "$POSTS"; return 1; }
    run jq -r '[.args[] | select(. == "from_project=proj-t2913")] | length' "$POSTS"
    [ "$status" -eq 0 ]
    echo "$output" | grep -vqx 1 && { echo "label count per post: $output"; cat "$POSTS"; return 1; }
    run jq -r '.idfile' "$POSTS"
    echo "$output" | grep -vqx "$PROJ/.context/rail.key" && { echo "idfiles: $output"; return 1; }
    return 0
}

@test "A1: agent-send turn post is project-signed and labelled" {
    run bash "$PROJ/scripts/agent-send.sh" --to-session peer --topic dm:a:b \
        --conversation-id cid-t2913 --timeout 2 --max-rings 1 --message hi
    [ "$status" -eq 0 ] || { echo "$output"; false; }
    _assert_all_posts_governed 1
}

@test "A2: agent-respond receipt and reply posts are project-signed and labelled" {
    run bash "$PROJ/scripts/agent-respond.sh" --topic dm:a:b \
        --conversation-id cid-t2913 --up-to 1 --reply "answer"
    [ "$status" -eq 0 ] || { echo "$output"; false; }
    _assert_all_posts_governed 2
    # positional topic stays first — the label is appended, not prepended
    [ "$(jq -r '.args[0]' "$POSTS" | sort -u)" = "dm:a:b" ]
}

@test "A3: chat-arc-broadcast per-hub post is project-signed and labelled" {
    printf '[hubs.one]\naddress = "10.0.0.1:9100"\n' > "$SB/hubs.toml"
    run bash "$PROJ/scripts/chat-arc-broadcast.sh" --payload hello --from me \
        --hubs-file "$SB/hubs.toml"
    [ "$status" -eq 0 ] || { echo "$output"; false; }
    _assert_all_posts_governed 1
}

@test "A4: listener-heartbeat post is project-signed and labelled" {
    run bash "$PROJ/scripts/listener-heartbeat.sh" --agent-id me --once
    [ "$status" -eq 0 ] || { echo "$output"; false; }
    _assert_all_posts_governed 1
}

@test "A5: pickup-channel-bridge mirror post is project-signed and labelled" {
    env_file="$SB/env.yaml"
    printf 'type: learning\nbody: x\n' > "$env_file"
    run env FRAMEWORK_ROOT="$REPO" bash "$REPO/lib/pickup-channel-bridge.sh" "$env_file"
    [ "$status" -eq 0 ]
    _assert_all_posts_governed 1
}

@test "A6: publish-learning-to-bus post is project-signed and labelled" {
    run env FRAMEWORK_ROOT="$REPO" L_ID=L-9 L_LEARNING=text L_SOURCE=P-001 \
        bash "$REPO/lib/publish-learning-to-bus.sh"
    [ "$status" -eq 0 ]
    _assert_all_posts_governed 1
}

@test "B: a caller-chosen identity (TERMLINK_AGENT_ID) is kept, not re-signed as the project" {
    TERMLINK_AGENT_ID=session-x run bash "$PROJ/scripts/agent-respond.sh" \
        --topic dm:a:b --conversation-id cid-t2913 --up-to 1
    [ "$status" -eq 0 ]
    [ "$(jq -r '.idfile' "$POSTS")" = "" ]
    [ "$(jq -r '[.args[] | select(. == "from_project=proj-t2913")] | length' "$POSTS")" = "1" ]
}

@test "C (control): without the framework lib the post is unlabelled and says so" {
    rm -rf "$PROJ/.agentic-framework"
    # break the in-repo fallbacks too: the copied script dir has no ../../lib
    run bash "$PROJ/scripts/agent-respond.sh" --topic dm:a:b \
        --conversation-id cid-t2913 --up-to 1
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "rail-identity.sh not found"
    [ "$(jq -r '[.args[] | select(startswith("from_project="))] | length' "$POSTS")" = "0" ]
}

@test "D: no direct termlink channel post remains in the six producers" {
    for f in lib/templates/scripts/agent-send.sh lib/templates/scripts/agent-respond.sh \
             lib/templates/scripts/chat-arc-broadcast.sh lib/templates/scripts/listener-heartbeat.sh \
             lib/pickup-channel-bridge.sh lib/publish-learning-to-bus.sh; do
        # non-comment lines invoking `channel post` other than the --help probe
        # and the declared no-lib fallback
        hits="$(grep -vE '^[[:space:]]*#' "$REPO/$f" \
                | grep -E '(termlink"?|TERMLINK\}?"?|\()[[:space:]]+channel[[:space:]]+post|=\(channel[[:space:]]+post' \
                | grep -vE -- '--help|rail_post_exec\(\)' || true)"
        [ -z "$hits" ] || { echo "$f: $hits"; false; }
    done
}
