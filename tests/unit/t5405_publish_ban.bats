#!/usr/bin/env bats
# T-5405 — publishing to Anthropic is blocked by default: deny rules from fw init/upgrade,
# config key PUBLISH_TO_ANTHROPIC (allow is operator-only), egress class `forbidden`,
# doctor/audit state line. Hermetic: temp projects, synthetic payloads; no publish tool is called.

load ../test_helper

HOOK="$FRAMEWORK_ROOT/agents/context/check-mcp-egress.sh"
PB="$FRAMEWORK_ROOT/lib/publish_ban.py"
TOOL='mcp__claude-artifacts__publish_files'
DOCS='mcp__claude_ai_Claude_Docs__create_doc'

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t5405-XXXXXX)"
    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ/.context/working" "$PROJ/.claude"
    export TEST_TEMP_DIR FRAMEWORK_ROOT PROJ
    unset FW_PUBLISH_TO_ANTHROPIC
}
teardown() {
    local i
    for i in 1 2 3 4 5; do
        [ -d "${TEST_TEMP_DIR:-}" ] || return 0
        rm -rf "$TEST_TEMP_DIR" 2>/dev/null && return 0
        sleep 1
    done
    return 0
}

_feed() { printf '%s' "$1" | PROJECT_ROOT="$PROJ" bash "$HOOK"; }
_payload() { printf '{"tool_name":"%s","tool_input":{}}' "$1"; }
_operator_approve() {   # tool [override]
    PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" python3 - "$@" <<'PY'
import sys
sys.path.insert(0, __import__("os").environ["FRAMEWORK_ROOT"] + "/lib")
import mcp_egress as m
m._is_agent = lambda: False
print(m.approve(sys.argv[1], "test", None, 30, len(sys.argv) > 2)["id"])
PY
}

@test "T-5405: ensure adds the seven deny entries, keeps the others, is idempotent" {
    printf '{"permissions":{"deny":["Bash(rm:*)"],"allow":["Read"]},"hooks":{"X":[]}}' > "$PROJ/.claude/settings.json"
    run python3 "$PB" ensure "$PROJ/.claude/settings.json" deny
    [ "$status" -eq 0 ]; [[ "$output" == added* ]]
    run python3 -c "
import json; d=json.load(open('$PROJ/.claude/settings.json'))
dn=d['permissions']['deny']
assert dn[0]=='Bash(rm:*)' and len(dn)==8, dn
for t in ['Artifact','ArtifactComments','ArtifactData','ArtifactCheck','DesignSync','mcp__claude-artifacts','mcp__claude_ai_Claude_Docs']: assert t in dn
assert d['permissions']['allow']==['Read'] and d['hooks']=={'X':[]}"
    [ "$status" -eq 0 ]
    run python3 "$PB" ensure "$PROJ/.claude/settings.json" deny
    [[ "$output" == none* ]]
}

@test "T-5405: allow removes exactly these entries and nothing else" {
    printf '{"permissions":{"deny":["Bash(rm:*)"]}}' > "$PROJ/.claude/settings.json"
    python3 "$PB" ensure "$PROJ/.claude/settings.json" deny >/dev/null
    run python3 "$PB" ensure "$PROJ/.claude/settings.json" allow
    [[ "$output" == removed* ]]
    run python3 -c "import json; print(json.load(open('$PROJ/.claude/settings.json'))['permissions']['deny'])"
    [ "$output" = "['Bash(rm:*)']" ]
}

@test "T-5405: unparseable settings are skipped, not clobbered" {
    echo '{broken' > "$PROJ/.claude/settings.json"
    run python3 "$PB" ensure "$PROJ/.claude/settings.json" deny
    [[ "$output" == skipped* ]]
    [ "$(cat "$PROJ/.claude/settings.json")" = '{broken' ]
}

@test "T-5405: config registry has the key, default deny, citing the ruling" {
    run bash -c "source '$FRAMEWORK_ROOT/lib/config.sh'; _fw_registry_default PUBLISH_TO_ANTHROPIC; echo; printf '%s\n' \"\${FW_CONFIG_REGISTRY[@]}\" | grep -c 'PUBLISH_TO_ANTHROPIC.*2026-11-24'"
    [ "$status" -eq 0 ]
    [[ "$output" == deny* ]]
    [[ "$output" == *1 ]]
}

@test "T-5405: setting allow is refused under agent control; deny is accepted" {
    run env CLAUDECODE=1 python3 "$PB" guard-set allow
    [ "$status" -eq 2 ]; [[ "$output" == *"operator's choice"* ]]
    run env CLAUDECODE=1 python3 "$PB" guard-set deny
    [ "$status" -eq 0 ]
}

@test "T-5405: fw config set allow is refused under agent control" {
    printf 'project_name: t\n' > "$PROJ/.framework.yaml"
    run env CLAUDECODE=1 PROJECT_ROOT="$PROJ" "$FRAMEWORK_ROOT/bin/fw" config set PUBLISH_TO_ANTHROPIC allow
    [ "$status" -ne 0 ]
    ! grep -q PUBLISH_TO_ANTHROPIC "$PROJ/.framework.yaml"
}

@test "T-5405: the forbidden tool is refused, naming ban, switch-off and one-use bypass" {
    for t in "$TOOL" "$DOCS" mcp__claude-artifacts__list_artifacts; do
        run _feed "$(_payload "$t")"
        [ "$status" -eq 2 ]
        [[ "$output" == *"blocked by default"* ]]
        [[ "$output" == *"--override-publish-ban"* ]]
        [[ "$output" == *"config set PUBLISH_TO_ANTHROPIC allow"* ]]
        [[ "$output" == *"bin/fw"* ]]
    done
}

@test "T-5405: an ordinary approval cannot be made and does not open a forbidden tool" {
    run bash -c "PROJECT_ROOT='$PROJ' FRAMEWORK_ROOT='$FRAMEWORK_ROOT' python3 - <<'PY'
import sys; sys.path.insert(0,'$FRAMEWORK_ROOT/lib')
import mcp_egress as m; m._is_agent=lambda: False
try: m.approve('$TOOL','r',None,30)
except m.EgressError as e: print(e)
PY"
    [[ "$output" == *"ordinary approval does not open it"* ]]
    # a row written by hand without the override marker does not open it either
    printf '{"id":"EG-x","tool":"%s","target":"","reason":"r","ts":"2026-01-01T00:00:00Z","expires":"2999-01-01T00:00:00Z","by":"operator"}\n' "$TOOL" > "$PROJ/.context/working/mcp-egress-approvals.jsonl"
    run _feed "$(_payload "$TOOL")"
    [ "$status" -eq 2 ]
}

@test "T-5405: a one-use override approval opens it exactly once" {
    _operator_approve "$TOOL" override >/dev/null
    run _feed "$(_payload "$TOOL")"; [ "$status" -eq 0 ]
    run _feed "$(_payload "$TOOL")"; [ "$status" -eq 2 ]
}

@test "T-5405: key=allow lifts the forbidden class; the ordinary egress rules then apply" {
    printf 'PUBLISH_TO_ANTHROPIC: allow\n' > "$PROJ/.framework.yaml"
    run _feed "$(_payload mcp__claude-artifacts__list_artifacts)"; [ "$status" -eq 0 ]
    run _feed "$(_payload "$TOOL")"; [ "$status" -eq 2 ]
    [[ "$output" == *"T-5394"* ]]
    [[ "$output" != *"blocked by default"* ]]
}

@test "T-5405: audit line: missing rules FAIL, present PASS blocked, allow PASS allowed" {
    run env PROJECT_ROOT="$PROJ" python3 "$PB" audit
    [[ "$output" == FAIL*"NOT blocked"* ]]
    printf '{}' > "$PROJ/.claude/settings.json"
    python3 "$PB" ensure "$PROJ/.claude/settings.json" deny >/dev/null
    run env PROJECT_ROOT="$PROJ" python3 "$PB" audit
    [[ "$output" == PASS*"blocked (default"* ]]
    printf 'PUBLISH_TO_ANTHROPIC: allow\n' > "$PROJ/.framework.yaml"
    run env PROJECT_ROOT="$PROJ" python3 "$PB" audit
    [[ "$output" == PASS*"allowed by operator"* ]]
}

@test "T-5405: egress audit (doctor/audit feed) carries the publish line" {
    run env PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" python3 "$FRAMEWORK_ROOT/lib/mcp_egress.py" audit
    [[ "$output" == *"publishing to Anthropic: NOT blocked"* ]]
}

@test "T-5405: fw init writes the deny rules; fw upgrade restores them and honours allow" {
    local P="$TEST_TEMP_DIR/consumer"; mkdir -p "$P"; git -C "$P" init -q
    run bash -c "cd '$P' && '$FRAMEWORK_ROOT/bin/fw' init '$P' --provider claude >/dev/null 2>&1; PROJECT_ROOT='$P' python3 '$PB' audit"
    [[ "$output" == PASS*"blocked (default"* ]]
    python3 "$PB" ensure "$P/.claude/settings.json" allow >/dev/null
    run bash -c "cd '$P' && '$FRAMEWORK_ROOT/bin/fw' upgrade '$P' >/dev/null 2>&1; PROJECT_ROOT='$P' python3 '$PB' audit"
    [[ "$output" == PASS*"blocked (default"* ]]
    printf 'PUBLISH_TO_ANTHROPIC: allow\n' >> "$P/.framework.yaml"
    run bash -c "cd '$P' && '$FRAMEWORK_ROOT/bin/fw' upgrade '$P' >/dev/null 2>&1; PROJECT_ROOT='$P' python3 '$PB' audit; python3 -c \"import json; print(json.load(open('$P/.claude/settings.json')).get('permissions',{}).get('deny',[]))\""
    [[ "$output" == *"allowed by operator"* ]]
    [[ "$output" == *"[]"* ]]
}
