#!/usr/bin/env bats
# T-5225 — TermLink-only rule: Claude Code's cross-session messaging tools
# (SendMessage, SendToProject, SendToProjectContext) are refused by the
# PreToolUse hook agents/context/block-cross-session-messages.sh, every other
# tool is allowed, an unreadable payload is refused (fail CLOSED), and the
# hook reaches consumers through `fw init` and `fw upgrade`.

load ../test_helper

HOOK="$FRAMEWORK_ROOT/agents/context/block-cross-session-messages.sh"
MATCHER="SendMessage|SendToProject|SendToProjectContext"

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t5225-XXXXXX)"
    export TEST_TEMP_DIR FRAMEWORK_ROOT
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_feed() { printf '%s' "$1" | bash "$HOOK"; }

_assert_refusal_text() {
    [[ "$output" == *"BLOCKED"* ]]
    [[ "$output" == *"TermLink"* ]]
    [[ "$output" == *"2026-11-17"* ]]
    [[ "$output" == *"2026-11-18"* ]]
    [[ "$output" == *"sidecar send --to <peer> --body"* ]]
}

# ── AC1: each listed tool is refused, exit 2, message names rule + route ──

@test "T-5225: SendMessage is refused with exit 2 and the TermLink route" {
    run _feed '{"tool_name":"SendMessage","tool_input":{"to":"peer","message":"hi"}}'
    [ "$status" -eq 2 ]
    _assert_refusal_text
    [[ "$output" == *"SendMessage"* ]]
}

@test "T-5225: SendToProject is refused with exit 2 and the TermLink route" {
    run _feed '{"tool_name":"SendToProject","tool_input":{}}'
    [ "$status" -eq 2 ]
    _assert_refusal_text
}

@test "T-5225: SendToProjectContext is refused with exit 2 and the TermLink route" {
    run _feed '{"tool_name":"SendToProjectContext","tool_input":{}}'
    [ "$status" -eq 2 ]
    _assert_refusal_text
}

@test "T-5225: non-matching tools are allowed silently (exit 0)" {
    local t
    for t in Bash Write Agent SendUserMessage ListAgents RemoteTrigger SendMessageX XSendMessage mcp__termlink__termlink_channel_post; do
        run _feed "{\"tool_name\":\"$t\",\"tool_input\":{}}"
        [ "$status" -eq 0 ] || { echo "tool $t: status $status"; false; }
        [ -z "$output" ] || { echo "tool $t printed: $output"; false; }
    done
}

@test "T-5225: malformed, empty or tool-less payload fails CLOSED (exit 2)" {
    local p
    for p in 'not json' '' '{}' '[]' '{"tool_name":42}'; do
        run _feed "$p"
        [ "$status" -eq 2 ] || { echo "payload [$p]: status $status"; false; }
        [[ "$output" == *"fail closed"* ]]
        [[ "$output" == *"sidecar send"* ]]
    done
}

@test "T-5225: hook is reachable as an fw hook subcommand" {
    run bash -c "printf '%s' '{\"tool_name\":\"SendMessage\"}' | '$FRAMEWORK_ROOT/bin/fw' hook block-cross-session-messages"
    [ "$status" -eq 2 ]
    [[ "$output" == *"sidecar send"* ]]
    run bash -c "printf '%s' '{\"tool_name\":\"Bash\"}' | '$FRAMEWORK_ROOT/bin/fw' hook block-cross-session-messages"
    [ "$status" -eq 0 ]
}

# ── AC2: delivered by fw init (template) and fw upgrade ──

_has_entry() {
    python3 - "$1" "$MATCHER" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
for b in d.get("hooks", {}).get("PreToolUse", []):
    if b.get("matcher") == sys.argv[2]:
        for h in b.get("hooks", []):
            if h.get("command", "").endswith("fw hook block-cross-session-messages"):
                sys.exit(0)
sys.exit(1)
PY
}

@test "T-5225: generate_claude_code_config template carries the matcher and hook" {
    grep -q "\"matcher\": \"$MATCHER\"" "$FRAMEWORK_ROOT/lib/init.sh"
    grep -q 'fw_prefix hook block-cross-session-messages' "$FRAMEWORK_ROOT/lib/init.sh"
}

@test "T-5225: fresh fw init consumer gets the PreToolUse entry" {
    mkdir -p "$TEST_TEMP_DIR/proj"
    run "$FRAMEWORK_ROOT/bin/fw" init "$TEST_TEMP_DIR/proj" --provider claude
    [ "$status" -eq 0 ]
    _has_entry "$TEST_TEMP_DIR/proj/.claude/settings.json"
}

@test "T-5225: fw upgrade delivers the entry to an existing consumer once the framework settings carry it" {
    # Upstream = committed HEAD with the operator's runme step applied (the same
    # fw hook-enable command), consumer = pre-existing settings.json without it.
    local work="$TEST_TEMP_DIR/up-work" bare="$TEST_TEMP_DIR/up.git" proj="$TEST_TEMP_DIR/consumer"
    git clone --quiet --shared "$FRAMEWORK_ROOT" "$work" 2>/dev/null
    # Framework side: strip the entry so the operator's command really adds it.
    python3 - "$work/.claude/settings.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
for b in d.get("hooks", {}).get("PreToolUse", []):
    b["hooks"] = [h for h in b.get("hooks", []) if "block-cross-session-messages" not in h.get("command", "")]
d["hooks"]["PreToolUse"] = [b for b in d["hooks"]["PreToolUse"] if b["hooks"]]
json.dump(d, open(sys.argv[1], "w"), indent=2)
PY
    # Consumer side: an fw-init-generated settings.json as it was before T-5225.
    mkdir -p "$TEST_TEMP_DIR/seed"
    "$FRAMEWORK_ROOT/bin/fw" init "$TEST_TEMP_DIR/seed" --provider claude >/dev/null 2>&1
    python3 - "$TEST_TEMP_DIR/seed/.claude/settings.json" "$TEST_TEMP_DIR/orig.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
d["hooks"]["PreToolUse"] = [b for b in d["hooks"]["PreToolUse"]
    if not any("block-cross-session-messages" in h.get("command", "") for h in b.get("hooks", []))]
json.dump(d, open(sys.argv[2], "w"), indent=2)
PY
    PROJECT_ROOT="$work" bash "$FRAMEWORK_ROOT/bin/hook-enable.sh" --name block-cross-session-messages \
        --matcher "$MATCHER" --event PreToolUse --file "$work/.claude/settings.json"
    (cd "$work" && git -c user.email=t@t -c user.name=t commit -qam "operator wires T-5225 hook")
    git clone --quiet --bare "$work" "$bare" 2>/dev/null

    mkdir -p "$proj/.claude"
    cp "$TEST_TEMP_DIR/orig.json" "$proj/.claude/settings.json"
    ! _has_entry "$proj/.claude/settings.json" || false
    git clone --quiet --depth=1 "file://$bare" "$proj/.agentic-framework" 2>/dev/null
    cat > "$proj/.framework.yaml" <<YAML
project_name: consumer
version: 1.0.0
provider: claude
upstream_repo: file://$bare
YAML
    run bash -c "cd '$proj' && env -i PATH=/usr/local/bin:/usr/bin:/bin HOME='$TEST_TEMP_DIR/home' \
        GIT_CEILING_DIRECTORIES='$(dirname "$TEST_TEMP_DIR")' FW_VERB_TELEMETRY=0 \
        '$proj/.agentic-framework/bin/fw' upgrade '$proj'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"block-cross-session-messages"* ]]
    _has_entry "$proj/.claude/settings.json"
}

# ── AC4: the operator's runme command is idempotent ──

@test "T-5225: the wiring command (fw hook-enable) adds the entry once and is idempotent" {
    local s="$TEST_TEMP_DIR/settings.json"
    echo '{"hooks":{"PreToolUse":[]}}' > "$s"
    run bash "$FRAMEWORK_ROOT/bin/hook-enable.sh" --name block-cross-session-messages --matcher "$MATCHER" --event PreToolUse --file "$s"
    [ "$status" -eq 0 ]
    _has_entry "$s"
    run bash "$FRAMEWORK_ROOT/bin/hook-enable.sh" --name block-cross-session-messages --matcher "$MATCHER" --event PreToolUse --file "$s"
    [ "$status" -eq 0 ]
    [[ "$output" == *"already registered"* ]]
    [ "$(grep -c 'block-cross-session-messages' "$s")" -eq 1 ]
}

# ── AC3: the rule is in the guidance every project receives ──

@test "T-5225: CLAUDE.md, FRAMEWORK.md and the consumer CLAUDE.md template state the rule" {
    local f
    for f in CLAUDE.md FRAMEWORK.md lib/templates/claude-project.md; do
        grep -q "T-5225" "$FRAMEWORK_ROOT/$f" || { echo "$f: no T-5225"; false; }
        grep -q "2026-11-18" "$FRAMEWORK_ROOT/$f" || { echo "$f: no ruling date"; false; }
        grep -q 'fw sidecar send --to <peer> --body' "$FRAMEWORK_ROOT/$f" || { echo "$f: no route"; false; }
        grep -q 'SendMessage' "$FRAMEWORK_ROOT/$f" || { echo "$f: no tool name"; false; }
    done
}
