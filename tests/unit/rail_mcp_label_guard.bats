#!/usr/bin/env bats
# T-2908: the MCP producer surface (mcp__termlink__termlink_channel_post) reaches
# the same rail topics as `fw rail post` with neither the T-2904 identity gate nor
# the T-2905 label gate in scope, because both live inside `do_rail post` in
# bin/fw and an MCP tool call never goes through that code path.
#
# Identity is NOT re-gated here — the MCP server resolves its signing key once,
# at process start, from an environment this hook cannot re-introspect per call
# (T-2908 measured the split; the mechanism inside termlink is opaque and out of
# our project boundary, T-559). This hook enforces the LABEL only: same
# detection surface as T-2905's shell-side auto-attach, applied at the one other
# call shape that reaches the topic. See CLAUDE.md L-572.
#
# RED-before-fix (T-2908 AC5): before check-rail-mcp-label.sh existed and before
# it was wired into .claude/settings.json, an MCP call with no from_project
# metadata reached termlink with nothing stopping it — the "blocked" test below
# is what makes that observable, and it fails against the pre-fix tree (no hook
# script) exactly as it must pass against the post-fix tree.

load ../test_helper

setup() {
    HOOK="$FRAMEWORK_ROOT/agents/context/check-rail-mcp-label.sh"
    TEST_ROOT="$(mktemp -d)"
    guard_project_root "$TEST_ROOT"
    mkdir -p "$TEST_ROOT/.context/working"
    export PROJECT_ROOT="$TEST_ROOT"
    export FRAMEWORK_ROOT="$FRAMEWORK_ROOT"
}

teardown() {
    rm -rf "${TEST_ROOT:-}" 2>/dev/null
    # Safety net: the CLI test below arms the token against the real repo
    # (fw's PROJECT_ROOT is cwd-derived, not env-overridable) — never leave
    # live-repo state behind on a failed assertion mid-test.
    rm -f "$FRAMEWORK_ROOT/.context/working/.rail-mcp-label-bypass" 2>/dev/null
}

mk_input() {
    # $1 = tool_name, $2 = metadata json (or '' for none)
    python3 -c "
import json, sys
tool_name = sys.argv[1]
md_raw = sys.argv[2]
ti = {'topic': 'some-topic', 'payload': 'x'}
if md_raw:
    ti['metadata'] = json.loads(md_raw)
print(json.dumps({'tool_name': tool_name, 'tool_input': ti}))
" "$1" "$2"
}

@test "rail-mcp-label: ignores tools other than the MCP channel_post surface" {
    input="$(mk_input 'Bash' '')"
    run bash "$HOOK" <<< "$input"
    [ "$status" -eq 0 ]
}

@test "rail-mcp-label: BLOCKED (exit 2) when metadata carries no from_project" {
    input="$(mk_input 'mcp__termlink__termlink_channel_post' '{"conversation_id": "x"}')"
    run bash "$HOOK" <<< "$input"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "BLOCKED"
    # The block message must name the way out, or the agent invents one (L-399).
    echo "$output" | grep -q "from_project"
    echo "$output" | grep -q "allow-unlabeled-mcp"
}

@test "rail-mcp-label: BLOCKED when metadata is entirely absent" {
    input="$(mk_input 'mcp__termlink__termlink_channel_post' '')"
    run bash "$HOOK" <<< "$input"
    [ "$status" -eq 2 ]
}

@test "rail-mcp-label: ALLOWED when metadata already carries from_project" {
    input="$(mk_input 'mcp__termlink__termlink_channel_post' '{"from_project": "999-agentic-engineering-framework"}')"
    run bash "$HOOK" <<< "$input"
    [ "$status" -eq 0 ]
}

@test "rail-mcp-label: the bypass token allows exactly one unlabeled call through, and logs Tier-2" {
    mkdir -p "$TEST_ROOT/.context/working"
    echo "- []" > "$TEST_ROOT/.context/working/.gate-bypass-log.yaml"
    date +%s > "$TEST_ROOT/.context/working/.rail-mcp-label-bypass"

    input="$(mk_input 'mcp__termlink__termlink_channel_post' '')"
    run bash "$HOOK" <<< "$input"
    [ "$status" -eq 0 ]

    # one-shot: token is consumed, a second unlabeled call blocks again
    run bash "$HOOK" <<< "$input"
    [ "$status" -eq 2 ]

    grep -q "rail-mcp-label" "$TEST_ROOT/.context/working/.gate-bypass-log.yaml"
}

@test "rail-mcp-label: a STALE bypass token does not allow the call through" {
    # 10000s old — well past any sane TTL.
    echo "$(( $(date +%s) - 10000 ))" > "$TEST_ROOT/.context/working/.rail-mcp-label-bypass"
    input="$(mk_input 'mcp__termlink__termlink_channel_post' '')"
    run bash "$HOOK" <<< "$input"
    [ "$status" -eq 2 ]
}

@test "rail-mcp-label: block message states the identity caveat (detection, not prevention, for signing key)" {
    input="$(mk_input 'mcp__termlink__termlink_channel_post' '')"
    run bash "$HOOK" <<< "$input"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "identity"
}

# --- companion CLI: `fw rail allow-unlabeled-mcp` arms the token ------------

@test "fw rail allow-unlabeled-mcp: arms a fresh bypass token the hook accepts" {
    # `fw`'s PROJECT_ROOT resolution is cwd-derived, not an env override (see
    # rail_identity_guard.bats for the same convention) — run it for real
    # against FRAMEWORK_ROOT and clean up the token file afterward so this
    # test cannot leave live-repo state behind.
    cd "$FRAMEWORK_ROOT"
    local real_token="$FRAMEWORK_ROOT/.context/working/.rail-mcp-label-bypass"
    rm -f "$real_token"

    run bin/fw rail allow-unlabeled-mcp
    [ "$status" -eq 0 ]
    [ -f "$real_token" ]

    input="$(mk_input 'mcp__termlink__termlink_channel_post' '')"
    run env PROJECT_ROOT="$FRAMEWORK_ROOT" bash "$HOOK" <<< "$input"
    [ "$status" -eq 0 ]
    [ ! -f "$real_token" ]  # one-shot: the hook consumed it
}
