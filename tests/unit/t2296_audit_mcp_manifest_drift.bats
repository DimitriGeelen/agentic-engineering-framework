#!/usr/bin/env bats
# T-2296 (arc-010): audit-side MCP manifest drift FAIL — daily-cron backstop
# to T-2294's pre-push gate.
#
# Surface under test: agents/audit/audit.sh block immediately after
# `# T-2296 / arc-010: MCP manifest drift FAIL`. The block routes
# `fw mcp check` exit codes (0/1/2) to pass/fail/info audit verdicts.
#
# Strategy: extract just the new block into a sub-shell test harness with
# stubbed `bin/fw mcp check`. The block is small and self-contained
# (only uses `pass`/`fail`/`info` shell functions + `$PROJECT_ROOT`), so we
# can simulate those functions and drive the three exit-code branches.

load ../test_helper

# Path to the audit script (source of truth for the block we're testing).
AUDIT_SH="$FRAMEWORK_ROOT/agents/audit/audit.sh"

# Extract the new T-2296 block as a shell snippet to source under test.
# Lines from `# T-2296 / arc-010` through the `fi` that closes the block.
_extract_block() {
    awk '
        /^# T-2296 \/ arc-010: MCP manifest drift FAIL/ { p=1 }
        p { print }
        p && /^fi$/ && !blockend { blockend=1; exit }
    ' "$AUDIT_SH"
}

# Build a stub bin/fw that responds to `mcp check` only — all other args
# exit silently. Exit code controlled by FW_STUB_MCP_EXIT.
_install_fw_stub() {
    mkdir -p "$TEST_TEMP_DIR/bin"
    cat > "$TEST_TEMP_DIR/bin/fw" <<'STUB'
#!/bin/bash
case "$1" in
    mcp)
        shift
        if [ "$1" = "check" ]; then
            case "${FW_STUB_MCP_EXIT:-0}" in
                0) echo "OK: manifest in sync (22 tools)"; exit 0 ;;
                1) echo "DRIFT: manifest differs from tool-set.yaml — regenerate via \`fw mcp emit-manifest\`" >&2; exit 1 ;;
                2) echo "ABSENT: agents/mcp/framework-mcp-manifest.json — run \`fw mcp emit-manifest\`" >&2; exit 2 ;;
            esac
        fi
        ;;
esac
exit 0
STUB
    chmod +x "$TEST_TEMP_DIR/bin/fw"
    # The block also gates on `[ -f "$PROJECT_ROOT/agents/mcp/manifest.py" ]`
    mkdir -p "$TEST_TEMP_DIR/agents/mcp"
    : > "$TEST_TEMP_DIR/agents/mcp/manifest.py"
}

# Run the extracted block with stubbed environment and capture pass/fail/info
# output via the test-mode functions.
_run_block_with_exit() {
    local exit_code="$1"
    _install_fw_stub
    local script="$TEST_TEMP_DIR/runner.sh"
    cat > "$script" <<RUNNER
#!/bin/bash
# Test-mode pass/fail/info: write the verdict label + message to stdout
# so the test can assert on it.
pass() { echo "PASS: \$*"; }
fail() { echo "FAIL: \$*"; }
info() { echo "INFO: \$*"; }
warn() { echo "WARN: \$*"; }
PROJECT_ROOT="$TEST_TEMP_DIR"
export FW_STUB_MCP_EXIT=$exit_code
RUNNER
    _extract_block >> "$script"
    bash "$script"
}

@test "t1: fw mcp check exits 0 (clean) → audit emits PASS line" {
    run _run_block_with_exit 0
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS:"* ]]
    [[ "$output" == *"framework-mcp manifest"* ]]
    [[ "$output" == *"in sync"* ]]
    [[ "$output" != *"FAIL:"* ]]
}

@test "t2: fw mcp check exits 1 (drift) → audit emits FAIL with remediation" {
    run _run_block_with_exit 1
    [ "$status" -eq 0 ]
    [[ "$output" == *"FAIL:"* ]]
    [[ "$output" == *"framework-mcp manifest"* ]]
    [[ "$output" == *"out of sync"* ]]
    # Remediation must be copy-pasteable and name emit-manifest
    [[ "$output" == *"fw mcp emit-manifest"* ]]
}

@test "t3: fw mcp check exits 2 (absent) → audit emits INFO (not FAIL — fresh project)" {
    run _run_block_with_exit 2
    [ "$status" -eq 0 ]
    [[ "$output" == *"INFO:"* ]]
    [[ "$output" == *"framework-mcp manifest"* ]]
    [[ "$output" == *"ABSENT"* ]]
    [[ "$output" != *"FAIL:"* ]]
}
