#!/usr/bin/env bats
# T-3559 — the producer/consumer contract of the sidecar-inbox hook, tested AT THE JOIN.
#
# `agents/context/sidecar-inbox.sh` is the only runtime adapter that puts peer mail in
# front of an agent. From 2026-09-24 to 2026-09-29 it surfaced nothing: T-3442 changed
# the producer (`fw sidecar inbox --peek --json`) from a bare list to
# {"consults": [...], "dm_rails": [...]}, and the hook still required a list. The hook's
# own suite stayed green throughout, because it faked the producer with the shape the
# hook expected rather than the shape the producer emitted.
#
# So this file fakes ONLY the true external boundary — the `termlink` binary, i.e. the
# hub — and runs the REAL producer (lib/sidecar_cli.py) into the REAL hook. If either
# side changes shape again, this goes red. That is the whole point: L-399, the bug lives
# at the join, so the test does too.

setup() {
    ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    HOOK="$ROOT/agents/context/sidecar-inbox.sh"
    SB="$(mktemp -d)"
    mkdir -p "$SB/bin" "$SB/state"

    # A fake hub. `channel subscribe inbox:* --cursor 0` returns one envelope in the
    # hub's real wire format (offset, metadata.from_agent, payload_b64) when
    # $FAKE_HAS_MAIL=1; everything else returns the empty forms the real hub uses.
    B64=$(printf 'what is the risk of shipping X?' | base64 | tr -d '\n')
    cat > "$SB/bin/termlink" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "$SB/termlink.log"
if [ "\$1 \$2" = "channel subscribe" ]; then
    cur=0; prev=""
    for a in "\$@"; do [ "\$prev" = "--cursor" ] && cur="\$a"; prev="\$a"; done
    case "\$3" in
        inbox:*)
            if [ "\${FAKE_HAS_MAIL:-1}" = "1" ] && [ "\$cur" = "0" ]; then
                echo '{"offset":0,"ts":1,"metadata":{"from_agent":"peer-agent","conversation_id":"conv-9","client_msg_id":"m1"},"payload_b64":"$B64"}'
            fi ;;
    esac
    exit 0
fi
if [ "\$1 \$2" = "channel list" ]; then echo '{"topics":[]}'; exit 0; fi
exit 0
EOF
    chmod +x "$SB/bin/termlink"

    # FW_BIN routes `fw sidecar ...` to the REAL producer, unmodified.
    cat > "$SB/bin/fw" <<EOF
#!/usr/bin/env bash
[ "\$1" = "sidecar" ] && shift
exec python3 "$ROOT/lib/sidecar_cli.py" "\$@"
EOF
    chmod +x "$SB/bin/fw"

    export PATH="$SB/bin:$PATH"
    export FW_BIN="$SB/bin/fw"
    # Cursor state lives under FRAMEWORK_ROOT (lib/sidecar/outbox.py:_root). Point it at
    # the sandbox so the live project's inbox cursors are never read or written.
    export FRAMEWORK_ROOT="$SB/state" PROJECT_ROOT="$SB/state"
    export FW_SIDECAR_IDENTITY_FP=aaaaaaaaaaaaaaaa FW_SIDECAR_HUB_ID=testhub FW_SIDECAR_HOST=testhost
    export SIDECAR_INBOX_TIMEOUT=20
    # Addressable, so a headless `claude -p` runner is not skipped by the hook (T-3684).
    export FW_SIDECAR_AGENT_ID=t3559-agent
}

teardown() { [ -n "${SB:-}" ] && rm -rf "$SB"; return 0; }

_hook() { bash "$HOOK" < /dev/null; }

@test "REAL producer -> REAL hook: a pending consult reaches the agent's context" {
    run _hook
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '"hookEventName": "UserPromptSubmit"'
    echo "$output" | grep -q 'peer-agent'
    echo "$output" | grep -q 'conv-9'
    echo "$output" | grep -q 'what is the risk of shipping X'
}

@test "CONTROL: a genuinely empty inbox through the real producer stays silent" {
    # Without this, a hook that always prints something passes the test above.
    export FAKE_HAS_MAIL=0
    run _hook
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "the real producer really ran — the hub was queried for an inbox topic" {
    # Guards the harness itself: if FW_BIN stopped reaching lib/sidecar_cli.py, the
    # tests above could pass or fail for reasons unrelated to the contract.
    run _hook
    grep -q 'channel subscribe inbox:' "$SB/termlink.log"
}

@test "PEEK holds end to end: surfacing twice shows the consult twice" {
    # A consuming read would advance the cursor, and the second run would be empty.
    run _hook
    echo "$output" | grep -q 'peer-agent'
    run _hook
    echo "$output" | grep -q 'peer-agent'
}

@test "the live project's cursor state is never touched" {
    before=$(md5sum "$ROOT/.context/sidecar/inbox-state.json" 2>/dev/null | awk '{print $1}')
    run _hook
    after=$(md5sum "$ROOT/.context/sidecar/inbox-state.json" 2>/dev/null | awk '{print $1}')
    [ "$before" = "$after" ]
}
