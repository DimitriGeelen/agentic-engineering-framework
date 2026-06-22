#!/usr/bin/env bats
# T-2459 (arc-010 slice 1C): framework MCP server framework/project root split
# + vendored-manifest catalogue fallback.
#
# The enabling fix so the vendored server works against a CONSUMER project:
#   - framework_root() — where assets live (bin/fw, agents/), from __file__ or
#                        FRAMEWORK_ROOT; in a consumer that's .agentic-framework/.
#   - project_root()   — what fw operates on (subprocess cwd); the parent of a
#                        vendored .agentic-framework/, else == framework_root().
#   - load_catalogue() — tool-set.yaml when present (framework/dev), else the
#                        enriched vendored manifest (consumer; policy/ unvendored).
#   - build_manifest() — now carries fw_command + description per tool (additive;
#                        scanner reads only name/gated).
#
# AC mapping (.tasks/active/T-2459-*.md):
#   AC1 framework_root vs project_root, both layouts — t1,t2,t3
#   AC2 catalogue from manifest when tool-set absent, else tool-set — t4,t5
#   AC3 fw runs with cwd=project_root for synthetic .agentic-framework — t6
#   AC5 no regression: manifest emit + scanner contract green — t7,t8
#
# Tests drive manifest.py directly (yaml-only, no `mcp` dep) for hermeticity;
# t9 exercises the live server build and is skipped when `mcp` is unavailable.

load ../test_helper

# Import the REAL manifest module via PYTHONPATH while letting FRAMEWORK_ROOT
# point at a synthetic layout — the two are deliberately independent (code
# location vs asset location). L-490: set env per python3 invocation, never
# rely on an inherited export.
MP() { echo "$FRAMEWORK_ROOT/agents/mcp"; }

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    REPO="$FRAMEWORK_ROOT"
    # Synthetic vendored consumer: <proj>/.agentic-framework/ with the assets a
    # consumer actually has (vendored agents/, bin/fw) but NO policy/.
    PROJ="$TEST_TEMP_DIR/myproject"
    VENDOR="$PROJ/.agentic-framework"
    mkdir -p "$VENDOR/agents/mcp" "$VENDOR/bin"
    : > "$VENDOR/bin/fw"
    chmod +x "$VENDOR/bin/fw"
    # Vendor a freshly-emitted (enriched) manifest into the synthetic layout.
    ( cd "$REPO" && bin/fw mcp emit-manifest >/dev/null 2>&1 )
    cp "$REPO/agents/mcp/framework-mcp-manifest.json" "$VENDOR/agents/mcp/framework-mcp-manifest.json"
}

teardown() {
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "t2459:t1 framework_root from __file__ when FRAMEWORK_ROOT unset == repo" {
    run env -u PROJECT_ROOT FRAMEWORK_ROOT= python3 -c "
import sys; sys.path.insert(0, '$(MP)')
import manifest
print(manifest.framework_root())
"
    [ "$status" -eq 0 ]
    [ "$output" = "$REPO" ]
}

@test "t2459:t2 framework layout — project_root() == framework_root()" {
    run env -u PROJECT_ROOT python3 -c "
import os, sys; sys.path.insert(0, '$(MP)')
os.environ['FRAMEWORK_ROOT'] = '$REPO'
import manifest
assert manifest.project_root() == manifest.framework_root(), (manifest.project_root(), manifest.framework_root())
print('ok', manifest.project_root())
"
    [ "$status" -eq 0 ]
    [[ "$output" == "ok $REPO" ]]
}

@test "t2459:t3 vendored layout — project_root() is the consumer (parent of .agentic-framework)" {
    run env -u PROJECT_ROOT python3 -c "
import os, sys; sys.path.insert(0, '$(MP)')
os.environ['FRAMEWORK_ROOT'] = '$VENDOR'
import manifest
fr = manifest.framework_root(); pr = manifest.project_root()
assert str(fr) == '$VENDOR', fr
assert str(pr) == '$PROJ', pr
print('ok', pr)
"
    [ "$status" -eq 0 ]
    [[ "$output" == "ok $PROJ" ]]
}

@test "t2459:t4 load_catalogue prefers tool-set.yaml in the framework repo" {
    run env -u PROJECT_ROOT python3 -c "
import os, sys; sys.path.insert(0, '$(MP)')
os.environ['FRAMEWORK_ROOT'] = '$REPO'
import manifest
cat = manifest.load_catalogue()
ro = cat['read_only']; aa = cat['agent_authority']
assert len(ro) >= 1 and len(aa) >= 1, (len(ro), len(aa))
# tool-set source carries fw_command (needed to actually run)
assert all('fw_command' in e for e in ro + aa)
print('ok', len(ro), len(aa))
"
    [ "$status" -eq 0 ]
    [[ "$output" == ok\ * ]]
}

@test "t2459:t5 load_catalogue falls back to vendored manifest when tool-set.yaml absent" {
    # FRAMEWORK_ROOT points at the synthetic vendored layout — NO policy/, so
    # the fallback path is exercised. Catalogue must still carry fw_command.
    run env -u PROJECT_ROOT python3 -c "
import os, sys; sys.path.insert(0, '$(MP)')
os.environ['FRAMEWORK_ROOT'] = '$VENDOR'
import manifest
assert not manifest.tool_set_path().is_file(), 'synthetic layout should not have tool-set.yaml'
cat = manifest.load_catalogue()
tools = cat['read_only'] + cat['agent_authority']
assert len(tools) >= 1, len(tools)
assert all('fw_command' in e and e['fw_command'] for e in tools), 'manifest fallback lost fw_command'
print('ok', len(tools))
"
    [ "$status" -eq 0 ]
    [[ "$output" == ok\ * ]]
}

@test "t2459:t6 vendored layout resolves fw binary in framework_root, cwd in project_root" {
    # AC3: the split that matters — bin/fw from framework_root (.agentic-framework),
    # operating dir (cwd) = project_root (the consumer checkout).
    run env -u PROJECT_ROOT python3 -c "
import os, sys; sys.path.insert(0, '$(MP)')
os.environ['FRAMEWORK_ROOT'] = '$VENDOR'
import manifest
fr = manifest.framework_root(); pr = manifest.project_root()
fw_bin = fr / 'bin' / 'fw'
assert fw_bin.is_file(), fw_bin            # binary lives with the framework
assert str(pr) == '$PROJ', pr              # cwd would be the consumer project
assert fr != pr, (fr, pr)                  # they diverge in a consumer
print('ok', fw_bin, '|', pr)
"
    [ "$status" -eq 0 ]
    [[ "$output" == ok\ * ]]
}

@test "t2459:t7 enriched manifest carries fw_command + description; scanner keys (name/gated) intact" {
    run env -u PROJECT_ROOT python3 -c "
import json, sys; sys.path.insert(0, '$(MP)')
m = json.load(open('$REPO/agents/mcp/framework-mcp-manifest.json'))
tools = m['tools']
assert len(tools) >= 1
for t in tools:
    assert 'name' in t and 'gated' in t, t          # scanner contract
    assert 'fw_command' in t and t['fw_command'], t  # T-2459 enrichment
    assert 'description' in t, t
print('ok', len(tools))
"
    [ "$status" -eq 0 ]
    [[ "$output" == ok\ * ]]
}

@test "t2459:t8 no regression: fw mcp check reports in-sync after emit" {
    cd "$REPO"
    run bin/fw mcp check
    [ "$status" -eq 0 ]
    [[ "$output" == *"in sync"* ]]
}

@test "t2459:t9 server builds + lists tools from vendored manifest (consumer case)" {
    if ! python3 -c "import mcp" 2>/dev/null; then
        skip "mcp package not importable on this host"
    fi
    run env -u PROJECT_ROOT python3 -c "
import os, sys; sys.path.insert(0, '$(MP)')
os.environ['FRAMEWORK_ROOT'] = '$VENDOR'
import framework_mcp_server as s
import manifest
cat = manifest.load_catalogue()
srv = s.build_server(cat)
assert srv is not None
# the index used to dispatch carries fw_command from the vendored manifest
idx = s._index_by_name(cat)
assert len(idx) >= 1
assert all('fw_command' in e for _, e in idx.values())
print('ok', len(idx))
"
    [ "$status" -eq 0 ]
    [[ "$output" == ok\ * ]]
}
