#!/usr/bin/env bats
# T-3407 — sidecar-inbox UserPromptSubmit hook: silent-when-empty, surfaces
# when pending, peeks (never consumes), fails open.

setup() {
    ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    HOOK="$ROOT/agents/context/sidecar-inbox.sh"
    SANDBOX="$(mktemp -d)"
    # A fake `fw` whose `sidecar inbox` returns whatever $FAKE_INBOX holds,
    # and records whether --peek was passed.
    mkdir -p "$SANDBOX/bin"
    cat > "$SANDBOX/bin/fw" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$FAKE_LOG"
if [ "${FAKE_MODE:-ok}" = "hang" ]; then sleep 30; fi
if [ "${FAKE_MODE:-ok}" = "fail" ]; then exit 1; fi
printf '%s' "$FAKE_INBOX"
EOF
    chmod +x "$SANDBOX/bin/fw"
    # A fake `termlink` on PATH so the presence check passes.
    printf '#!/usr/bin/env bash\nexit 0\n' > "$SANDBOX/bin/termlink"
    chmod +x "$SANDBOX/bin/termlink"
    export FW_BIN="$SANDBOX/bin/fw"
    export FAKE_LOG="$SANDBOX/calls.log"
    export PATH="$SANDBOX/bin:$PATH"
    export SIDECAR_INBOX_TIMEOUT=2
}

teardown() { rm -rf "$SANDBOX"; }

@test "empty inbox: no stdout, exit 0 — a silent turn costs nothing" {
    export FAKE_INBOX='[]'
    run bash "$HOOK" < /dev/null
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "pending consult: emits UserPromptSubmit additionalContext carrying sender, conversation and body" {
    export FAKE_INBOX='[{"offset":3,"client_msg_id":"m1","from":"peer-agent","conversation_id":"conv-9","body":"what is the risk?","ts":1}]'
    run bash "$HOOK" < /dev/null
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '"hookEventName": "UserPromptSubmit"'
    echo "$output" | grep -q 'peer-agent'
    echo "$output" | grep -q 'conv-9'
    echo "$output" | grep -q 'what is the risk'
    echo "$output" | grep -q 'fw sidecar inbox'
}

@test "the hook PEEKS: it passes --peek and never a consuming read" {
    export FAKE_INBOX='[{"offset":0,"from":"a","conversation_id":"c","body":"b"}]'
    run bash "$HOOK" < /dev/null
    [ "$status" -eq 0 ]
    grep -q -- '--peek' "$FAKE_LOG"
    ! grep -vq -- '--peek' "$FAKE_LOG"   # every fw call in the log carried --peek
}

@test "fail open: fw exits non-zero -> no stdout, exit 0" {
    export FAKE_MODE=fail FAKE_INBOX=''
    run bash "$HOOK" < /dev/null
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "fail open: malformed JSON from fw -> no stdout, exit 0" {
    export FAKE_INBOX='this is not json'
    run bash "$HOOK" < /dev/null
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "fail open: hung fw is cut by the timeout -> no stdout, exit 0" {
    export FAKE_MODE=hang FAKE_INBOX=''
    run bash "$HOOK" < /dev/null
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "fail open: no termlink on PATH -> no stdout, exit 0, fw never called" {
    rm -f "$SANDBOX/bin/termlink"
    # The real termlink lives in /usr/local/bin; drop that from PATH so the
    # presence check genuinely fails, while keeping coreutils and python3.
    export PATH="$SANDBOX/bin:/usr/bin:/bin"
    export FAKE_INBOX='[{"offset":0,"from":"a","conversation_id":"c","body":"b"}]'
    run bash "$HOOK" < /dev/null
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -f "$FAKE_LOG" ]
}
