#!/usr/bin/env bats
# T-2272 (arc-010 Slice 2.5): framework-mcp .mcp.json fragment helper.
#
# Surfaces under test:
#   - agents/mcp/framework-mcp.mcp-fragment.json — static JSON contract
#   - bin/fw mcp wire-fragment — print verb (cats the file)
#   - bin/fw mcp help — lists wire-fragment subcommand
#
# AC mapping (per .tasks/active/T-2272-*.md):
#   Fragment is valid JSON                    — t1
#   Fragment shape: framework-mcp + cmd+args  — t2
#   Fragment args path resolves to server     — t3
#   `wire-fragment` verb prints valid JSON    — t4
#   Output matches fragment byte-for-byte     — t5
#   Help block lists wire-fragment            — t6

load ../test_helper

setup() {
    # L-456: project-root-aware tools require PROJECT_ROOT unset to use FRAMEWORK_ROOT default.
    unset PROJECT_ROOT
    export FRAMEWORK_ROOT
    # Mirror test_helper's TEST_TEMP_DIR setup so teardown's rm guard passes.
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
}

@test "t2272:t1 fragment file is valid JSON" {
    run python3 -c "import json; json.load(open('$FRAMEWORK_ROOT/agents/mcp/framework-mcp.mcp-fragment.json'))"
    [ "$status" -eq 0 ]
}

@test "t2272:t2 fragment shape: framework-mcp key with command + args" {
    run python3 -c "
import json
d = json.load(open('$FRAMEWORK_ROOT/agents/mcp/framework-mcp.mcp-fragment.json'))
assert 'framework-mcp' in d, 'missing framework-mcp key'
entry = d['framework-mcp']
assert 'command' in entry, 'missing command'
assert 'args' in entry, 'missing args'
assert isinstance(entry['args'], list), 'args not list'
assert len(entry['args']) >= 1, 'args empty'
"
    [ "$status" -eq 0 ]
}

@test "t2272:t3 fragment args path resolves to framework_mcp_server.py" {
    run python3 -c "
import json, os
d = json.load(open('$FRAMEWORK_ROOT/agents/mcp/framework-mcp.mcp-fragment.json'))
path = d['framework-mcp']['args'][-1]
# Either absolute (resolves directly) or relative (resolves under FRAMEWORK_ROOT)
resolved = path if os.path.isabs(path) else os.path.join('$FRAMEWORK_ROOT', path)
assert os.path.isfile(resolved), 'server script not found: ' + resolved
assert resolved.endswith('framework_mcp_server.py'), 'wrong target: ' + resolved
"
    [ "$status" -eq 0 ]
}

@test "t2272:t4 fw mcp wire-fragment prints valid JSON to stdout" {
    run "$FRAMEWORK_ROOT/bin/fw" mcp wire-fragment
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'framework-mcp' in d"
}

@test "t2272:t5 wire-fragment output matches fragment file byte-for-byte" {
    out=$("$FRAMEWORK_ROOT/bin/fw" mcp wire-fragment)
    expected=$(cat "$FRAMEWORK_ROOT/agents/mcp/framework-mcp.mcp-fragment.json")
    [ "$out" = "$expected" ]
}

@test "t2272:t6 fw mcp help block lists wire-fragment" {
    run "$FRAMEWORK_ROOT/bin/fw" mcp
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "wire-fragment"
}
