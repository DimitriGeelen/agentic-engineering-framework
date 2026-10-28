#!/usr/bin/env bats
# T-2293 (arc-010 follow-on): fw mcp check — focused exit-code drift verb
# for CI / pre-commit / scripts (sibling to fw vendor self --dry-run).
#
# Surfaces under test:
#   - agents/mcp/manifest.py main(['check', ...]) — md5 compare emitted vs on-disk
#   - bin/fw mcp check                            — dispatcher routes to manifest.py
#
# Exit-code contract (per T-2293 ACs):
#   0 → in sync (tool-set.yaml matches framework-mcp-manifest.json)
#   1 → drift (mutation made; regenerate via `fw mcp emit-manifest`)
#   2 → manifest absent (never emitted, or unreadable)

load ../test_helper
load helpers/mcp_fixture

# T-4862: every test runs bin/fw from a private framework tree (helpers/mcp_fixture),
# never the live repo. This file used to emit, edit and delete the live manifest and
# tool-set.yaml and restore them in teardown; parallel files raced on them (T-4861).
setup() {
    mcp_live_guard_begin
    mcp_fixture_make
}

teardown() {
    mcp_fixture_cleanup
    mcp_live_guard_end
}

@test "t1: in-sync state → exit 0 with OK message" {
    run mcp_fw mcp check
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK:"* ]]
    [[ "$output" == *"in sync"* ]]
}

@test "t2: drift state → exit 1 with DRIFT message" {
    # Mutate tool-set.yaml so emitted manifest would differ from on-disk.
    python3 -c "
import yaml
p = '$MCP_FIX/policy/capability-overlay/tool-set.yaml'
d = yaml.safe_load(open(p))
d['read_only'].append({'name': 'fake_drift_tool_t2293', 'rationale': 'test'})
yaml.safe_dump(d, open(p,'w'), sort_keys=False)
"
    run mcp_fw mcp check
    [ "$status" -eq 1 ]
    [[ "$output" == *"DRIFT:"* ]]
    [[ "$output" == *"fw mcp emit-manifest"* ]]
}

@test "t3: manifest absent → exit 2 with ABSENT message" {
    rm -f "$MCP_FIX/agents/mcp/framework-mcp-manifest.json"
    run mcp_fw mcp check
    [ "$status" -eq 2 ] || { echo "status=$status output=$output"; false; }
    [[ "$output" == *"ABSENT:"* ]]
    # T-4862: the verb looked in the fixture, not the live repo.
    [[ "$output" == *"$MCP_FIX/agents/mcp/framework-mcp-manifest.json"* ]]
    [[ "$output" == *"fw mcp emit-manifest"* ]]
}

@test "t4: help text includes new check verb" {
    run mcp_fw mcp help
    [ "$status" -eq 0 ]
    [[ "$output" == *"check"* ]]
    [[ "$output" == *"sync/drift/absent"* ]]
}

@test "t5: control — the live guard fails a test that changes a guarded file (T-4862)" {
    # Run against a temp root so the control never touches the live repo.
    local root="$MCP_FIX_TMP/guardroot"
    mkdir -p "$root/agents/mcp" "$root/policy/capability-overlay"
    echo '{}' > "$root/agents/mcp/framework-mcp-manifest.json"
    echo 'read_only: []' > "$root/policy/capability-overlay/tool-set.yaml"
    run env FRAMEWORK_ROOT="$root" bash -c 'source "$1"; mcp_live_guard_begin
        echo "read_only: [x]" > "$FRAMEWORK_ROOT/policy/capability-overlay/tool-set.yaml"
        mcp_live_guard_end' _ "$BATS_TEST_DIRNAME/helpers/mcp_fixture.bash"
    [ "$status" -ne 0 ]
    [[ "$output" == *"changed the live MCP manifest"* ]]
    run env FRAMEWORK_ROOT="$root" bash -c 'source "$1"; mcp_live_guard_begin
        chmod 600 "$FRAMEWORK_ROOT/agents/mcp/framework-mcp-manifest.json"; mcp_live_guard_end' \
        _ "$BATS_TEST_DIRNAME/helpers/mcp_fixture.bash"
    [ "$status" -ne 0 ]
    run env FRAMEWORK_ROOT="$root" bash -c 'source "$1"; mcp_live_guard_begin; mcp_live_guard_end' \
        _ "$BATS_TEST_DIRNAME/helpers/mcp_fixture.bash"
    [ "$status" -eq 0 ]
}
