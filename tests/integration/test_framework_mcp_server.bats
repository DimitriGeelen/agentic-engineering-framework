#!/usr/bin/env bats
# T-2265 (arc-010 Slice 2): integration tests for framework MCP server.
#
# Surfaces under test:
#   - agents/mcp/manifest.py       — emit manifest from tool-set.yaml
#   - agents/mcp/framework_mcp_server.py — stdio MCP server
#   - bin/fw mcp emit-manifest|status|start|stop — CLI lifecycle
#   - agents/audit/orchestrator-mcp-scan.sh probe_framework_tools() — drift scan
#
# AC mapping (per .tasks/active/T-2265-*.md):
#   manifest emitted from tool-set.yaml          — t1
#   manifest contract (name+gated only)          — t2
#   16 read_only + 6 agent_authority             — t3
#   sovereignty_bound_excluded NEVER emitted     — t4
#   agent_authority requires task_id schema      — t5
#   server initialize + tools/list handshake     — t6
#   audit scan picks up manifest                 — t7
#   fw mcp status + help                         — t8

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"
MANIFEST_PY="$FRAMEWORK_ROOT/agents/mcp/manifest.py"
SERVER_PY="$FRAMEWORK_ROOT/agents/mcp/framework_mcp_server.py"
TOOL_SET="$FRAMEWORK_ROOT/policy/capability-overlay/tool-set.yaml"
DEFAULT_MANIFEST="$FRAMEWORK_ROOT/agents/mcp/framework-mcp-manifest.json"

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-mcp-t2265-XXXXXX)"
    export NO_COLOR=1
    # Default uses the live FRAMEWORK_ROOT — server reads tool-set there.
    export FRAMEWORK_ROOT
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ─────────────────────────────────────────────────────────────────
# Manifest emission
# ─────────────────────────────────────────────────────────────────

@test "t2265 t1: manifest.py emit writes manifest from tool-set.yaml" {
    [ -f "$TOOL_SET" ]
    [ -f "$MANIFEST_PY" ]
    run python3 "$MANIFEST_PY" emit
    [ "$status" -eq 0 ]
    [[ "$output" == *"Wrote"* ]]
    [ -f "$DEFAULT_MANIFEST" ]
}

@test "t2265 t2: manifest contract — every entry has name + gated, nothing else required" {
    [ -f "$DEFAULT_MANIFEST" ] || python3 "$MANIFEST_PY" emit >/dev/null
    run python3 -c "
import json
m = json.load(open('$DEFAULT_MANIFEST'))
assert 'tools' in m, 'missing tools'
for t in m['tools']:
    assert 'name' in t, f'missing name: {t}'
    assert 'gated' in t, f'missing gated: {t}'
    assert isinstance(t['gated'], bool), f'gated not bool: {t}'
print('OK')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "t2265 t3: manifest count — 22 tools (16 read_only + 6 agent_authority)" {
    [ -f "$DEFAULT_MANIFEST" ] || python3 "$MANIFEST_PY" emit >/dev/null
    run python3 -c "
import json
m = json.load(open('$DEFAULT_MANIFEST'))
tools = m['tools']
gated = [t for t in tools if t['gated']]
ungated = [t for t in tools if not t['gated']]
print(f'total={len(tools)} gated={len(gated)} ungated={len(ungated)}')
assert len(tools) == 22, len(tools)
assert len(gated) == 6, len(gated)
assert len(ungated) == 16, len(ungated)
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"total=22 gated=6 ungated=16"* ]]
}

@test "t2265 t4: sovereignty_bound_excluded NEVER appears in manifest" {
    [ -f "$DEFAULT_MANIFEST" ] || python3 "$MANIFEST_PY" emit >/dev/null
    run python3 -c "
import json
m = json.load(open('$DEFAULT_MANIFEST'))
names = {t['name'] for t in m['tools']}
forbidden = {'bvp_confirm', 'inception_decide', 'arc_close', 'tier0_approve', 'enforcement_baseline'}
leak = names & forbidden
assert not leak, f'sovereignty-bound leaked: {leak}'
print('OK no-sovereignty-leak')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK no-sovereignty-leak"* ]]
}

# ─────────────────────────────────────────────────────────────────
# Server handshake (MCP JSONRPC over stdio)
# ─────────────────────────────────────────────────────────────────

@test "t2265 t5: agent_authority tools require task_id with T-XXX pattern" {
    out=$(printf '%s\n' \
        '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0"}}}' \
        '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
        '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
        | timeout 8 python3 "$SERVER_PY" 2>/dev/null | tail -1)
    echo "$out" | python3 -c "
import json, sys
data = json.load(sys.stdin)
tools = {t['name']: t for t in data['result']['tools']}
authority = ['work_on', 'task_update', 'note', 'context_focus', 'context_add_learning', 'assumption_add']
for n in authority:
    assert n in tools, f'missing {n}'
    s = tools[n]['inputSchema']
    assert 'task_id' in s.get('required', []), f'{n} missing required task_id'
    assert s['properties']['task_id'].get('pattern') == r'^T-\d+\$', f'{n} bad pattern'
print('OK agent-authority-schema')
"
    [ "$?" -eq 0 ]
}

@test "t2265 t6: server initialize + tools/list returns 22 tools" {
    out=$(printf '%s\n' \
        '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0"}}}' \
        '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
        '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
        | timeout 8 python3 "$SERVER_PY" 2>/dev/null)
    # Two responses: initialize (id=1) + tools/list (id=2)
    n=$(echo "$out" | python3 -c "
import sys, json
lines = [l for l in sys.stdin if l.strip()]
listing = json.loads(lines[-1])
print(len(listing['result']['tools']))
")
    [ "$n" = "22" ]
}

# ─────────────────────────────────────────────────────────────────
# CLI lifecycle + audit hookup
# ─────────────────────────────────────────────────────────────────

@test "t2265 t7: fw mcp status surfaces tools / gated count + audit scan picks up manifest" {
    # Ensure manifest exists at default path.
    "$FW" mcp emit-manifest >/dev/null
    run "$FW" mcp status
    [ "$status" -eq 0 ]
    [[ "$output" == *"22"* ]]
    [[ "$output" == *"gated: 6"* ]]
    # Audit scan must report "Framework-mcp: pass" with 6/22 gated count.
    scan_out=$(bash "$FRAMEWORK_ROOT/agents/audit/orchestrator-mcp-scan.sh" 2>&1 || true)
    echo "$scan_out" | grep -qE "Framework-mcp: pass — 6/22 tools gated"
}

@test "t2265 t8: fw mcp help lists new subcommands (T-2265 contract)" {
    run "$FW" mcp help
    [ "$status" -eq 0 ]
    [[ "$output" == *"emit-manifest"* ]]
    [[ "$output" == *"start"* ]]
    [[ "$output" == *"status"* ]]
    [[ "$output" == *"T-2265"* ]]
}
