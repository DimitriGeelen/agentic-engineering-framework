#!/usr/bin/env bats
# T-1346-B3 / T-1407: install.sh scans for vendored consumer projects.
# Three cases:
#   - zero consumers found
#   - some consumers found (printed with version)
#   - --no-scan suppresses output

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
INSTALL="$FRAMEWORK_ROOT/install.sh"

setup() {
    SCAN_DIR=$(mktemp -d)
}

teardown() {
    rm -rf "$SCAN_DIR"
}

# Helper: extract scan_vendored_consumers + its env into a runnable shim and call it
run_scan() {
    local no_scan="${1:-false}"
    bash -c "
        set -euo pipefail
        NO_SCAN='$no_scan'
        FW_CONSUMER_SCAN_DIRS='$SCAN_DIR'
        BOLD=''; NC=''; GREEN=''; YELLOW=''; RED=''
        info() { echo \"[+] \$*\"; }
        warn() { echo \"[!] \$*\"; }
        $(sed -n '/^scan_vendored_consumers()/,/^}$/p' "$INSTALL")
        scan_vendored_consumers
    "
}

@test "T-1407: install scan reports (none) when no vendored consumers found" {
    run run_scan false
    [ "$status" -eq 0 ]
    [[ "$output" == *"Vendored framework copies detected:"* ]]
    [[ "$output" == *"(none)"* ]]
}

@test "T-1407: install scan lists vendored consumers with version" {
    # Create two fake vendored projects
    mkdir -p "$SCAN_DIR/proj-a/.agentic-framework"
    mkdir -p "$SCAN_DIR/proj-b/.agentic-framework"
    echo "framework" > "$SCAN_DIR/proj-a/.agentic-framework/FRAMEWORK.md"
    echo "framework" > "$SCAN_DIR/proj-b/.agentic-framework/FRAMEWORK.md"
    echo "1.2.3" > "$SCAN_DIR/proj-a/.agentic-framework/VERSION"
    echo "0.9.0" > "$SCAN_DIR/proj-b/.agentic-framework/VERSION"

    run run_scan false
    [ "$status" -eq 0 ]
    [[ "$output" == *"proj-a (v1.2.3)"* ]]
    [[ "$output" == *"proj-b (v0.9.0)"* ]]
    [[ "$output" == *"2 vendored consumer project(s) found"* ]]
}

@test "T-1407: install scan handles missing VERSION file" {
    mkdir -p "$SCAN_DIR/proj-x/.agentic-framework"
    echo "framework" > "$SCAN_DIR/proj-x/.agentic-framework/FRAMEWORK.md"

    run run_scan false
    [ "$status" -eq 0 ]
    [[ "$output" == *"proj-x (v?)"* ]]
}

@test "T-1407: --no-scan suppresses scan output" {
    mkdir -p "$SCAN_DIR/proj-c/.agentic-framework"
    echo "framework" > "$SCAN_DIR/proj-c/.agentic-framework/FRAMEWORK.md"

    run run_scan true
    [ "$status" -eq 0 ]
    [[ "$output" == *"skipped (--no-scan)"* ]]
    [[ "$output" != *"proj-c"* ]]
}

@test "T-1407: install scan ignores directories without FRAMEWORK.md" {
    mkdir -p "$SCAN_DIR/not-a-project/.agentic-framework"
    # No FRAMEWORK.md → should not be listed

    run run_scan false
    [ "$status" -eq 0 ]
    [[ "$output" == *"(none)"* ]]
    [[ "$output" != *"not-a-project"* ]]
}

@test "T-1407: install.sh --help advertises --no-scan" {
    run bash "$INSTALL" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--no-scan"* ]]
}
