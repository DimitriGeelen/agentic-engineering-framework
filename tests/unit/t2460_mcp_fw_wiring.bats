#!/usr/bin/env bats
# T-2460 (arc-010 / T-2458 slice 1C-wiring): fw init/upgrade wire the `fw` MCP
# server into a consumer's .mcp.json.
#
# The server entry for consumers is:
#   "fw": {"command": "python3",
#          "args": [".agentic-framework/agents/mcp/framework_mcp_server.py"]}
# — consumer-relative path (NOT the framework's own agents/mcp/...), key `fw`
# (so tools surface as mcp__fw__*; L-467 prefix = mcpServers key).
#
# Behavioral (do_upgrade --dry-run reaches step [6/10] and runs the real
# recommended-servers detection) + decisive source-pins for the literal
# heredocs (what's in the heredoc IS what gets written).
#
# AC mapping (.tasks/active/T-2460-*.md):
#   AC1 init create template carries fw         — t5 (source-pin: literal heredoc)
#   AC2 upgrade adds/creates fw, recommended    — t1,t2,t6
#   AC3 path consumer-relative + resolves       — t3,t4
#   AC5 no regression / new wiring coverage      — this file + suite run

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t2460-XXXXXX)"
    export TEST_TEMP_DIR
    export FRAMEWORK_ROOT
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

teardown() {
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Minimal consumer fixture: proj/.agentic-framework/ (own git) + .framework.yaml.
# FRAMEWORK_ROOT stays the real worktree, target is a separate dir → do_upgrade
# proceeds the normal path (not bare-from-consumer) and reaches the .mcp.json step.
make_consumer() {
    local proj="$1"
    mkdir -p "$proj/.agentic-framework"
    (cd "$proj/.agentic-framework" && git init -q 2>/dev/null && touch FRAMEWORK.md && \
        git add FRAMEWORK.md && git -c user.email=t@t -c user.name=t commit -q -m init 2>/dev/null)
    cat > "$proj/.framework.yaml" <<YAML
project_name: $(basename "$proj")
version: 1.4.0
provider: claude
YAML
}

@test "t2460:t1 upgrade dry-run on consumer with NO .mcp.json → WOULD CREATE includes fw" {
    local proj="$TEST_TEMP_DIR/create-proj"
    make_consumer "$proj"
    run do_upgrade "$proj" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *".mcp.json"* ]]
    echo "$output" | grep -E "WOULD CREATE.*\.mcp\.json" | grep -q "fw"
}

@test "t2460:t2 upgrade dry-run on consumer missing fw → WOULD ADD names fw (existing preserved)" {
    local proj="$TEST_TEMP_DIR/merge-proj"
    make_consumer "$proj"
    cat > "$proj/.mcp.json" <<'JSON'
{ "mcpServers": { "context7": { "command": "npx", "args": ["-y", "@upstash/context7-mcp"] } } }
JSON
    run do_upgrade "$proj" --dry-run
    [ "$status" -eq 0 ]
    echo "$output" | grep -E "WOULD ADD.*MCP" | grep -q "fw"
}

@test "t2460:t3 wired args path is consumer-relative (.agentic-framework/agents/mcp/...)" {
    # Both init.sh and upgrade.sh must use the consumer-relative path, never the
    # framework's own agents/mcp/... (which would point fw at the wrong dir).
    grep -q '\.agentic-framework/agents/mcp/framework_mcp_server\.py' "$FRAMEWORK_ROOT/lib/init.sh"
    grep -q '\.agentic-framework/agents/mcp/framework_mcp_server\.py' "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

@test "t2460:t4 consumer path resolves to a real server script under the framework" {
    # The path the consumer entry points at (relative to consumer root) maps to
    # this file in the vendored .agentic-framework/ — assert it exists at source.
    [ -f "$FRAMEWORK_ROOT/agents/mcp/framework_mcp_server.py" ]
}

@test "t2460:t5 init.sh .mcp.json template includes the fw server entry" {
    # Literal heredoc → grep is the behavioral truth for the create path.
    run python3 -c "
import re
src = open('$FRAMEWORK_ROOT/lib/init.sh').read()
assert '\"fw\": {' in src, 'no fw key in init.sh'
assert 'agents/mcp/framework_mcp_server.py' in src
print('ok')
"
    [ "$status" -eq 0 ]
    [[ "$output" == "ok" ]]
}

@test "t2460:t6 upgrade.sh recommended_servers + both defaults maps carry fw" {
    # recommended_servers includes fw (drives missing-detection)
    grep -q '"context7":1,"playwright":1,"termlink":1,"fw":1' "$FRAMEWORK_ROOT/lib/upgrade.sh"
    # merge-missing python defaults map has fw
    grep -q "'fw': {'command': 'python3'" "$FRAMEWORK_ROOT/lib/upgrade.sh"
    # create-new heredoc has the fw entry (count: defaults-map + heredoc => >=2 mentions of the path)
    local n
    n=$(grep -c 'agents/mcp/framework_mcp_server.py' "$FRAMEWORK_ROOT/lib/upgrade.sh")
    [ "$n" -ge 2 ]
}
