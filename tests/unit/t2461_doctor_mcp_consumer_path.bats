#!/usr/bin/env bats
# T-2461: fw doctor's framework-MCP-manifest check resolved its asset paths
# against $PROJECT_ROOT, which is the CONSUMER root in a vendored install — the
# manifest actually lives under $FRAMEWORK_ROOT (.agentic-framework/agents/mcp/).
# Result: doctor SKIPped misleadingly on every consumer ("manifest absent — run:
# fw mcp emit-manifest"), even though the manifest is present (vendored) and
# emit-manifest can't run there (no tool-set.yaml).
#
# Fix: asset paths use ${FRAMEWORK_ROOT:-$PROJECT_ROOT}; the runtime pid file
# stays on $PROJECT_ROOT. In the framework repo FRAMEWORK_ROOT==PROJECT_ROOT so
# this is a no-op (no regression); in a consumer it resolves the vendored path.
#
# These are fast checks: a source-pin on the check + a behavioral replay of the
# exact resolution snippet against synthetic framework/consumer layouts. We do
# NOT invoke `fw doctor` (slow, network-coupled) — the path logic is the unit.
#
# T-4543: T-3801 moved the check verbatim out of bin/fw into
# lib/doctor-drift.sh:doctor_check_mcp_manifest (as `local` declarations), so
# the source pins target that file; t0 pins that doctor still calls it.

load ../test_helper

setup() {
    BIN_FW="$FRAMEWORK_ROOT/bin/fw"
    CHECK_SRC="$FRAMEWORK_ROOT/lib/doctor-drift.sh"
    TEST_TEMP_DIR="$(mktemp -d -t fw-t2461-XXXXXX)"
    export TEST_TEMP_DIR
}

teardown() {
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "t2461:t0 doctor sources doctor-drift.sh and calls the MCP manifest check" {
    grep -q 'source "\$FRAMEWORK_ROOT/lib/doctor-drift.sh"' "$BIN_FW"
    grep -qE '^[[:space:]]+doctor_check_mcp_manifest[[:space:]]*$' "$BIN_FW"
}

@test "t2461:t1 doctor MCP block resolves asset paths via FRAMEWORK_ROOT fallback" {
    grep -q 'local _fw_root="\${FRAMEWORK_ROOT:-\$PROJECT_ROOT}"' "$CHECK_SRC"
    grep -q 'local _mcp_mf="\$_fw_root/agents/mcp/framework-mcp-manifest.json"' "$CHECK_SRC"
    grep -q 'local _mcp_ts="\$_fw_root/policy/capability-overlay/tool-set.yaml"' "$CHECK_SRC"
}

@test "t2461:t2 manifest.py emit path uses _fw_root (not PROJECT_ROOT)" {
    grep -q 'python3 "\$_fw_root/agents/mcp/manifest.py" show' "$CHECK_SRC"
}

@test "t2461:t3 runtime pid file stays on PROJECT_ROOT (not _fw_root)" {
    # The MCP server pid is per-project runtime state, written into the
    # operating project's .context/working/ — must NOT move to _fw_root.
    grep -q 'local _mcp_pid_f="\$PROJECT_ROOT/.context/working/framework-mcp.pid"' "$CHECK_SRC"
}

@test "t2461:t4 resolution finds vendored manifest in a consumer layout" {
    # Synthetic consumer: project root + vendored .agentic-framework with the
    # manifest under agents/mcp/. FRAMEWORK_ROOT points at the vendored dir.
    local proj="$TEST_TEMP_DIR/consumer"
    local fwr="$proj/.agentic-framework"
    mkdir -p "$fwr/agents/mcp"
    echo '{"tools":[]}' > "$fwr/agents/mcp/framework-mcp-manifest.json"

    # Replay the exact resolution snippet from bin/fw.
    PROJECT_ROOT="$proj" FRAMEWORK_ROOT="$fwr" run bash -c '
        _fw_root="${FRAMEWORK_ROOT:-$PROJECT_ROOT}"
        _mcp_mf="$_fw_root/agents/mcp/framework-mcp-manifest.json"
        [ -f "$_mcp_mf" ] && echo FOUND || echo ABSENT
    '
    [ "$status" -eq 0 ]
    [ "$output" = "FOUND" ]

    # The OLD logic ($PROJECT_ROOT) would have missed it → ABSENT (the bug).
    PROJECT_ROOT="$proj" run bash -c '
        _mcp_mf="$PROJECT_ROOT/agents/mcp/framework-mcp-manifest.json"
        [ -f "$_mcp_mf" ] && echo FOUND || echo ABSENT
    '
    [ "$output" = "ABSENT" ]
}

@test "t2461:t5 no-regression: framework-repo layout (FRAMEWORK_ROOT==PROJECT_ROOT) resolves identically" {
    # In the framework repo the two roots are the same dir, so the fallback is a
    # no-op and the real manifest is found exactly as before.
    local root="$TEST_TEMP_DIR/fwrepo"
    mkdir -p "$root/agents/mcp"
    echo '{"tools":[]}' > "$root/agents/mcp/framework-mcp-manifest.json"

    PROJECT_ROOT="$root" FRAMEWORK_ROOT="$root" run bash -c '
        _fw_root="${FRAMEWORK_ROOT:-$PROJECT_ROOT}"
        [ -f "$_fw_root/agents/mcp/framework-mcp-manifest.json" ] && echo FOUND || echo ABSENT
    '
    [ "$output" = "FOUND" ]
}

@test "t2461:t6 consumer SKIP hint points at fw upgrade (re-vendor), not emit-manifest" {
    grep -q 'manifest absent in vendored framework — run: fw upgrade' "$CHECK_SRC"

    # Behavioural: call the real check in a consumer layout with no manifest.
    local proj="$TEST_TEMP_DIR/consumer"
    mkdir -p "$proj/.agentic-framework/agents/mcp"
    PROJECT_ROOT="$proj" FRAMEWORK_ROOT="$proj/.agentic-framework" CHECK_SRC="$CHECK_SRC" \
        run bash -c 'source "$CHECK_SRC"; doctor_check_mcp_manifest'
    [ "$status" -eq 0 ]
    [[ "$output" == *"manifest absent in vendored framework — run: fw upgrade"* ]]
    [[ "$output" != *"emit-manifest"* ]]
}
