#!/usr/bin/env bats
# T-2417: Claude Code session adapter — verifies canonical-JSONL emission per
# agents/sessions/SCHEMA.md from a stubbed `claude agents --all --json` response.
#
# We stub `claude` on PATH with canned JSON that covers the full state matrix
# observed in the 2026-06-16 live probe:
#   - background sessions with `state` ∈ {blocked, done, failed}, `id` field
#   - interactive sessions with `status` ∈ {busy, idle}, `pid` field
#   - cwd inside a git repo (project=basename) vs cwd outside (project=loose)
#
# AC mapping:
#   t1  no claude on PATH → exit 2 with diagnostic
#   t2  malformed JSON → exit 3
#   t3  blocked → needs-input
#   t4  done → completed
#   t5  failed → completed + description="failed"
#   t6  busy (interactive) → working
#   t7  idle (interactive) → completed
#   t8  cwd in git repo → project = basename(toplevel)
#   t9  cwd in $HOME → project = "(loose)"
#   t10 empty session array → exit 0, zero lines (valid)

load ../test_helper

ADAPTER="$FRAMEWORK_ROOT/agents/sessions/claude-code/list.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    # Stub directory we prepend to PATH so our fake `claude` wins.
    STUB_DIR="$TEST_TEMP_DIR/bin"
    mkdir -p "$STUB_DIR"
    # Real git repo so project_for can resolve a basename.
    FAKE_REPO="$TEST_TEMP_DIR/my-real-project"
    mkdir -p "$FAKE_REPO"
    git -C "$FAKE_REPO" init -q
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

# Helper to write a stub `claude` that emits a chosen JSON string when called
# with `agents --all --json`.
_stub_claude() {
    local json="$1"
    cat > "$STUB_DIR/claude" <<EOF
#!/usr/bin/env bash
if [ "\$1" = "agents" ]; then
    cat <<JSONEOF
$json
JSONEOF
    exit 0
fi
echo "stub: unexpected args: \$*" >&2
exit 1
EOF
    chmod +x "$STUB_DIR/claude"
}

@test "t1: no claude on PATH → exit 2" {
    run env PATH="/usr/bin:/bin" "$ADAPTER"
    [ "$status" -eq 2 ]
    [[ "$output" == *"not on PATH"* ]]
}

@test "t2: malformed JSON → exit 3" {
    _stub_claude "not-json-at-all"
    run env PATH="$STUB_DIR:$PATH" "$ADAPTER"
    [ "$status" -eq 3 ]
    [[ "$output" == *"malformed JSON"* ]]
}

@test "t3: blocked → needs-input" {
    _stub_claude '[{"id":"x","cwd":"'"$FAKE_REPO"'","kind":"background","startedAt":1780000000000,"sessionId":"sid1","name":"test","state":"blocked"}]'
    run env PATH="$STUB_DIR:$PATH" "$ADAPTER"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"state":"needs-input"'* ]]
}

@test "t4: done → completed" {
    _stub_claude '[{"id":"x","cwd":"'"$FAKE_REPO"'","kind":"background","startedAt":1780000000000,"sessionId":"sid1","name":"test","state":"done"}]'
    run env PATH="$STUB_DIR:$PATH" "$ADAPTER"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"state":"completed"'* ]]
}

@test "t5: failed → completed + description=failed" {
    _stub_claude '[{"id":"x","cwd":"'"$FAKE_REPO"'","kind":"background","startedAt":1780000000000,"sessionId":"sid1","name":"test","state":"failed"}]'
    run env PATH="$STUB_DIR:$PATH" "$ADAPTER"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"state":"completed"'* ]]
    [[ "$output" == *'"description":"failed"'* ]]
}

@test "t6: interactive busy → working" {
    _stub_claude '[{"pid":1234,"cwd":"'"$FAKE_REPO"'","kind":"interactive","startedAt":1780000000000,"sessionId":"sid1","name":"test","status":"busy"}]'
    run env PATH="$STUB_DIR:$PATH" "$ADAPTER"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"state":"working"'* ]]
}

@test "t7: interactive idle → completed" {
    _stub_claude '[{"pid":1234,"cwd":"'"$FAKE_REPO"'","kind":"interactive","startedAt":1780000000000,"sessionId":"sid1","name":"test","status":"idle"}]'
    run env PATH="$STUB_DIR:$PATH" "$ADAPTER"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"state":"completed"'* ]]
}

@test "t8: cwd in git repo → project = basename(toplevel)" {
    _stub_claude '[{"id":"x","cwd":"'"$FAKE_REPO"'","kind":"background","startedAt":1780000000000,"sessionId":"sid1","name":"test","state":"done"}]'
    run env PATH="$STUB_DIR:$PATH" "$ADAPTER"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"project":"my-real-project"'* ]]
}

@test "t9: cwd in \$HOME → project = (loose)" {
    _stub_claude '[{"id":"x","cwd":"'"$HOME"'","kind":"background","startedAt":1780000000000,"sessionId":"sid1","name":"test","state":"done"}]'
    run env PATH="$STUB_DIR:$PATH" "$ADAPTER"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"project":"(loose)"'* ]]
}

@test "t10: empty session array → exit 0, zero JSONL lines" {
    _stub_claude '[]'
    run env PATH="$STUB_DIR:$PATH" "$ADAPTER"
    [ "$status" -eq 0 ]
    # Zero JSONL output expected (no sessions).
    [ -z "$output" ]
}
