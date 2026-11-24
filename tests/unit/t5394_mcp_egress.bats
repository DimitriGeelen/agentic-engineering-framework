#!/usr/bin/env bats
# T-5394 (G-140) — MCP egress gate: the PreToolUse hook agents/context/check-mcp-egress.sh
# (matcher `mcp__.*`) refuses MCP tools that can move data off the host unless the
# operator approved that one use; the approval is operator-only; classification is data
# (policy/mcp-egress.yaml); the hook reaches consumers through `fw init` and `fw upgrade`.
#
# Hermetic: every case runs against a temp PROJECT_ROOT with synthetic payloads. No MCP
# tool is ever called.

load ../test_helper

HOOK="$FRAMEWORK_ROOT/agents/context/check-mcp-egress.sh"
MATCHER='mcp__.*'
PUBLISH='mcp__termlink__termlink_send'   # an ordinary egress tool; claude-artifacts is forbidden since T-5405

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t5394-XXXXXX)"
    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ/.context/working" "$PROJ/.claude"
    export TEST_TEMP_DIR FRAMEWORK_ROOT PROJ
}

teardown() {
    # fw init can leave a background git write finishing in the new repo's .git: retry.
    local i
    for i in 1 2 3 4 5; do
        [ -d "${TEST_TEMP_DIR:-}" ] || return 0
        rm -rf "$TEST_TEMP_DIR" 2>/dev/null && return 0
        sleep 1
    done
    return 0
}

_feed() { printf '%s' "$1" | PROJECT_ROOT="$PROJ" bash "$HOOK"; }

# Operator approval written through the real approve() with only the agent check stubbed
# (this suite itself runs under an agent, so the verb would — correctly — refuse).
_operator_approve() {   # tool [target] [ttl]
    PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" python3 - "$@" <<'PY'
import sys
sys.path.insert(0, __import__("os").environ["FRAMEWORK_ROOT"] + "/lib")
import mcp_egress as m
m._is_agent = lambda: False
tool = sys.argv[1]
target = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else None
ttl = int(sys.argv[3]) if len(sys.argv) > 3 else 30
print(m.approve(tool, "test approval", target, ttl)["id"])
PY
}

# ── AC1: allow non-egress, refuse egress, fail closed ──

@test "T-5394: a local MCP tool is allowed" {
    run _feed '{"tool_name":"mcp__fw__task_list","tool_input":{}}'
    [ "$status" -eq 0 ]
    run _feed '{"tool_name":"mcp__termlink__termlink_list_sessions","tool_input":{}}'
    [ "$status" -eq 0 ]
    [ "$status" -eq 0 ]
}

@test "T-5394: a non-MCP tool is allowed" {
    run _feed '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
    [ "$status" -eq 0 ]
}

@test "T-5394: an egress MCP tool without approval is refused with the operator's approve line" {
    run _feed "{\"tool_name\":\"$PUBLISH\",\"tool_input\":{\"files\":[\"letter.pdf\"]}}"
    [ "$status" -eq 2 ]
    printf '%s\n' "$output" | grep -qx 'FW-DENY: mcp-egress (T-5394)'
    [[ "$output" == *"BLOCKED: $PUBLISH"* ]]
    [[ "$output" == *"move data off this host"* ]]
    [[ "$output" == *"You cannot approve it yourself"* ]]
    [[ "$output" == *"show the content inside the conversation"* ]]
    [[ "$output" == *"egress approve $PUBLISH --reason"* ]]
    [[ "$output" == *"cd "* ]]
}

@test "T-5394: TermLink cross-host sends are refused, reads are not" {
    for t in termlink_remote_exec termlink_file_send termlink_channel_post termlink_dispatch termlink_agent_contact; do
        run _feed "{\"tool_name\":\"mcp__termlink__$t\",\"tool_input\":{}}"
        [ "$status" -eq 2 ] || { echo "not refused: $t"; false; }
    done
}

@test "T-5394: an unreadable payload is refused (fail closed)" {
    run _feed 'not json at all'
    [ "$status" -eq 2 ]
    [[ "$output" == *"fail closed"* ]]
    run _feed ''
    [ "$status" -eq 2 ]
    run _feed '{"tool_input":{}}'
    [ "$status" -eq 2 ]
}

@test "T-5394: a missing or broken policy refuses every MCP tool (fail closed)" {
    local fw="$TEST_TEMP_DIR/fw"
    mkdir -p "$fw/lib" "$fw/policy" "$fw/agents/context"
    cp "$FRAMEWORK_ROOT/lib/mcp_egress.py" "$fw/lib/"
    cp "$HOOK" "$fw/agents/context/"
    echo 'rules: [ {match: x' > "$fw/policy/mcp-egress.yaml"
    run bash -c "printf '%s' '{\"tool_name\":\"mcp__fw__task_list\"}' | PROJECT_ROOT='$PROJ' FRAMEWORK_ROOT='$fw' bash '$fw/agents/context/check-mcp-egress.sh'"
    [ "$status" -eq 2 ]
    [[ "$output" == *"cannot be read"* ]]
}

# ── AC2: classification is data; unknown verb-named tools are egress ──

@test "T-5394: an unknown tool whose name carries an egress verb is refused" {
    for t in mcp__mail__send_message mcp__gh__create_issue mcp__drive__upload_file mcp__x__share_doc mcp__x__delete_record mcp__x__post mcp__notion__create_page; do
        run _feed "{\"tool_name\":\"$t\",\"tool_input\":{}}"
        [ "$status" -eq 2 ] || { echo "not refused: $t"; false; }
        [[ "$output" == *"treated as egress until policy/mcp-egress.yaml classifies it"* ]]
    done
}

@test "T-5394: an unknown tool with no egress verb is allowed and reported unclassified" {
    run _feed '{"tool_name":"mcp__weather__get_forecast","tool_input":{}}'
    [ "$status" -eq 0 ]
    run env PROJECT_ROOT="$PROJ" python3 "$FRAMEWORK_ROOT/lib/mcp_egress.py" classify mcp__weather__get_forecast
    [[ "$output" == local*unclassified* ]]
}

@test "T-5394: the policy file parses and seeds 050's claude-artifacts and TermLink lists" {
    python3 - "$FRAMEWORK_ROOT/policy/mcp-egress.yaml" <<'PY'
import sys, yaml, fnmatch
d = yaml.safe_load(open(sys.argv[1]))
rules = d["rules"]
def cls(name):
    for r in rules:
        if fnmatch.fnmatchcase(name, r["match"]):
            return r["class"]
for t in ("publish_files publish_version edit_version create_from_type upload_asset copy_file "
          "copy_asset db_write db_str_replace reply_comment reply_shared_comment resolve_comment "
          "pin_artifact declare_capabilities watch").split():
    assert cls("mcp__claude-artifacts__" + t) in ("egress", "forbidden"), t  # T-5405: forbidden first
for t in ("remote_exec file_send dispatch batch_exec batch_run exec inject interact run send spawn "
          "broadcast chat_arc_broadcast emit emit_to request kv_set channel_post channel_reply "
          "channel_forward channel_quote channel_edit agent_post agent_reply agent_quote agent_edit "
          "agent_ask agent_contact agent_send_auto_discover").split():
    assert cls("mcp__termlink__termlink_" + t) == "egress", t
assert cls("mcp__termlink__termlink_list_sessions") == "local"
PY
}

@test "T-5394: a project rule can add egress but cannot loosen a framework egress rule" {
    mkdir -p "$PROJ/.context/project"
    cat > "$PROJ/.context/project/mcp-egress.yaml" <<'YAML'
rules:
  - match: "mcp__weather__get_forecast"
    class: egress
    reason: project says so
  - match: "mcp__claude-artifacts__publish_files"
    class: local
    reason: attempt to loosen
YAML
    run _feed '{"tool_name":"mcp__weather__get_forecast","tool_input":{}}'
    [ "$status" -eq 2 ]
    run _feed "{\"tool_name\":\"$PUBLISH\",\"tool_input\":{}}"
    [ "$status" -eq 2 ]
}

# ── approvals: single use, target-bound, expiring, duplicate fire ──

@test "T-5394: an operator approval allows exactly one call, then it is used" {
    id=$(_operator_approve "$PUBLISH")
    [[ "$id" == EG-* ]]
    run _feed "{\"tool_name\":\"$PUBLISH\",\"tool_input\":{},\"tool_use_id\":\"tu-1\"}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"allowed once by operator approval $id"* ]]
    run _feed "{\"tool_name\":\"$PUBLISH\",\"tool_input\":{},\"tool_use_id\":\"tu-2\"}"
    [ "$status" -eq 2 ]
    run env PROJECT_ROOT="$PROJ" python3 "$FRAMEWORK_ROOT/lib/mcp_egress.py" list
    [[ "$output" == *"$id"*used* ]]
}

@test "T-5394: a duplicate hook fire of the same tool call is re-admitted without a second approval" {
    _operator_approve "$PUBLISH" >/dev/null
    run _feed "{\"tool_name\":\"$PUBLISH\",\"tool_input\":{},\"tool_use_id\":\"tu-dup\"}"
    [ "$status" -eq 0 ]
    run _feed "{\"tool_name\":\"$PUBLISH\",\"tool_input\":{},\"tool_use_id\":\"tu-dup\"}"
    [ "$status" -eq 0 ]
    run _feed "{\"tool_name\":\"$PUBLISH\",\"tool_input\":{},\"tool_use_id\":\"tu-other\"}"
    [ "$status" -eq 2 ]
}

@test "T-5394: an approval for one tool does not open another" {
    _operator_approve "mcp__termlink__termlink_broadcast" >/dev/null
    run _feed "{\"tool_name\":\"$PUBLISH\",\"tool_input\":{}}"
    [ "$status" -eq 2 ]
}

@test "T-5394: a target-bound approval opens only a call whose input names the target" {
    _operator_approve "$PUBLISH" "art-123" >/dev/null
    run _feed "{\"tool_name\":\"$PUBLISH\",\"tool_input\":{\"artifact\":\"art-999\"}}"
    [ "$status" -eq 2 ]
    run _feed "{\"tool_name\":\"$PUBLISH\",\"tool_input\":{\"artifact\":\"art-123\"}}"
    [ "$status" -eq 0 ]
}

@test "T-5394: an expired approval does not open the call" {
    _operator_approve "$PUBLISH" "" 1 >/dev/null
    python3 - "$PROJ/.context/working/mcp-egress-approvals.jsonl" <<'PY'
import json, sys
p = sys.argv[1]
rows = [json.loads(l) for l in open(p) if l.strip()]
for r in rows:
    r["expires"] = "2000-01-01T00:00:00Z"
open(p, "w").write("".join(json.dumps(r) + "\n" for r in rows))
PY
    run _feed "{\"tool_name\":\"$PUBLISH\",\"tool_input\":{}}"
    [ "$status" -eq 2 ]
}

# ── AC3: approval is operator-only ──

@test "T-5394: fw egress approve refuses under CLAUDECODE=1, even with --i-am-human" {
    run env CLAUDECODE=1 PROJECT_ROOT="$PROJ" python3 "$FRAMEWORK_ROOT/lib/mcp_egress.py" approve "$PUBLISH" --reason r --i-am-human
    [ "$status" -ne 0 ]
    [[ "$output" == *"REFUSED"* ]]
    [[ "$output" == *"--i-am-human does not lift it"* ]]
    [ ! -s "$PROJ/.context/working/mcp-egress-approvals.jsonl" ]
}

@test "T-5394: approve refuses with CLAUDECODE unset but AI_AGENT or the entrypoint set" {
    run env -u CLAUDECODE AI_AGENT=1 PROJECT_ROOT="$PROJ" python3 "$FRAMEWORK_ROOT/lib/mcp_egress.py" approve "$PUBLISH" --reason r
    [ "$status" -ne 0 ]
    run env -u CLAUDECODE -u AI_AGENT CLAUDE_CODE_ENTRYPOINT=cli PROJECT_ROOT="$PROJ" python3 "$FRAMEWORK_ROOT/lib/mcp_egress.py" approve "$PUBLISH" --reason r
    [ "$status" -ne 0 ]
    [ ! -s "$PROJ/.context/working/mcp-egress-approvals.jsonl" ]
}

@test "T-5394: approve refuses through the process-ancestry check with every env signal cleared" {
    # A fake 'claude' ancestor: exec -a renames bash, which then runs the verb as its child.
    run env -u CLAUDECODE -u AI_AGENT -u CLAUDE_CODE_ENTRYPOINT PROJECT_ROOT="$PROJ" \
        bash -c "exec -a claude bash -c 'python3 \"$FRAMEWORK_ROOT/lib/mcp_egress.py\" approve $PUBLISH --reason r; echo rc=\$?'"
    [[ "$output" == *"REFUSED"* ]]
    [ ! -s "$PROJ/.context/working/mcp-egress-approvals.jsonl" ]
}

@test "T-5394: agent Write and Bash writes to the approval ledger are refused" {
    run bash -c "printf '%s' '{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$PROJ/.context/working/mcp-egress-approvals.jsonl\",\"content\":\"{}\"}}' | CLAUDECODE=1 python3 '$FRAMEWORK_ROOT/agents/context/check-human-ac-tick.py'"
    [ "$status" -eq 2 ]
    [[ "$output" == *"operator-only record"* ]]
    run bash -c "printf '%s' '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo x >> .context/working/mcp-egress-approvals.jsonl\"}}' | CLAUDECODE=1 python3 '$FRAMEWORK_ROOT/agents/context/check-human-ac-tick.py'"
    [ "$status" -eq 2 ]
}

@test "T-5394: approve rejects wildcards and a missing reason" {
    run env PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" python3 - <<'PY'
import os, sys
sys.path.insert(0, os.environ["FRAMEWORK_ROOT"] + "/lib")
import mcp_egress as m
m._is_agent = lambda: False
for tool, reason in (("mcp__x__*", "r"), ("publish_files", "r"), ("mcp__x__send", " ")):
    try:
        m.approve(tool, reason, None, 30)
    except m.EgressError:
        continue
    raise SystemExit(f"accepted {tool!r}")
print("ok")
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *ok* ]]
}

# ── AC4: audit lists egress tools with their gate, FAILs when unwired ──

@test "T-5394: audit FAILs when the hook is not wired and lists the egress rules per server" {
    cat > "$PROJ/.mcp.json" <<'J'
{"mcpServers": {"termlink": {"command": "termlink"}, "claude-artifacts": {"command": "x"}}}
J
    echo '{"hooks":{"PreToolUse":[]}}' > "$PROJ/.claude/settings.json"
    run env HOME="$TEST_TEMP_DIR/home" PROJECT_ROOT="$PROJ" python3 "$FRAMEWORK_ROOT/lib/mcp_egress.py" audit
    [ "$status" -eq 0 ]
    printf '%s\n' "$output" | grep -q "^FAIL	MCP egress hook not wired"
    printf '%s\n' "$output" | grep -q "^FAIL	MCP server 'claude-artifacts'.*publish_files.*gate: NONE"
    printf '%s\n' "$output" | grep -q "^FAIL	MCP server 'termlink'.*termlink_remote_\*"
    printf '%s\n' "$output" | grep -q "^INFO	claude.ai connectors"
}

@test "T-5394: audit PASSes with the hook wired and names the gate" {
    cat > "$PROJ/.mcp.json" <<'J'
{"mcpServers": {"claude-artifacts": {"command": "x"}}}
J
    cat > "$PROJ/.claude/settings.json" <<'J'
{"hooks":{"PreToolUse":[{"matcher":"mcp__.*","hooks":[{"type":"command","command":"bin/fw hook check-mcp-egress"}]}]}}
J
    python3 "$FRAMEWORK_ROOT/lib/publish_ban.py" ensure "$PROJ/.claude/settings.json" deny >/dev/null   # T-5405
    run env HOME="$TEST_TEMP_DIR/home" PROJECT_ROOT="$PROJ" python3 "$FRAMEWORK_ROOT/lib/mcp_egress.py" audit
    ! printf '%s\n' "$output" | grep -q "^FAIL" || false
    printf '%s\n' "$output" | grep -q "^PASS	MCP server 'claude-artifacts'.*gate: PreToolUse check-mcp-egress"
    printf '%s\n' "$output" | grep -q "^PASS	MCP egress hook wired"
}

@test "T-5394: fw audit and fw doctor call the egress check" {
    grep -q 'lib/mcp_egress.py" audit' "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    grep -q 'lib/mcp_egress.py" audit' "$FRAMEWORK_ROOT/bin/fw"
}

# ── AC5: delivery ──

_has_entry() {
    python3 - "$1" "$MATCHER" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
for b in d.get("hooks", {}).get("PreToolUse", []):
    if b.get("matcher") == sys.argv[2]:
        for h in b.get("hooks", []):
            if h.get("command", "").endswith("fw hook check-mcp-egress"):
                sys.exit(0)
sys.exit(1)
PY
}

@test "T-5394: fw init writes the PreToolUse entry" {
    mkdir -p "$TEST_TEMP_DIR/newproj"
    run "$FRAMEWORK_ROOT/bin/fw" init "$TEST_TEMP_DIR/newproj" --provider claude
    [ "$status" -eq 0 ]
    _has_entry "$TEST_TEMP_DIR/newproj/.claude/settings.json"
}

@test "T-5394: this framework's settings.json carries the entry (the source fw upgrade delivers from)" {
    _has_entry "$FRAMEWORK_ROOT/.claude/settings.json"
}

@test "T-5394: fw upgrade delivers the entry to an existing consumer" {
    local work="$TEST_TEMP_DIR/up-work" bare="$TEST_TEMP_DIR/up.git" proj="$TEST_TEMP_DIR/consumer"
    git clone --quiet --shared "$FRAMEWORK_ROOT" "$work" 2>/dev/null
    # Upstream = HEAD plus this working tree's T-5394 files (the test must not depend on commit order).
    local f
    for f in lib/mcp_egress.py policy/mcp-egress.yaml agents/context/check-mcp-egress.sh lib/init.sh .claude/settings.json; do
        mkdir -p "$work/$(dirname "$f")"; cp "$FRAMEWORK_ROOT/$f" "$work/$f"
    done
    (cd "$work" && git add -A && git -c user.email=t@t -c user.name=t commit -qa --allow-empty -m "T-5394 under test")
    git clone --quiet --bare "$work" "$bare" 2>/dev/null

    mkdir -p "$TEST_TEMP_DIR/seed"
    "$FRAMEWORK_ROOT/bin/fw" init "$TEST_TEMP_DIR/seed" --provider claude >/dev/null 2>&1
    mkdir -p "$proj/.claude"
    python3 - "$TEST_TEMP_DIR/seed/.claude/settings.json" "$proj/.claude/settings.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
d["hooks"]["PreToolUse"] = [b for b in d["hooks"]["PreToolUse"]
    if not any("check-mcp-egress" in h.get("command", "") for h in b.get("hooks", []))]
json.dump(d, open(sys.argv[2], "w"), indent=2)
PY
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
    _has_entry "$proj/.claude/settings.json"
}
