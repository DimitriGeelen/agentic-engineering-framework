#!/usr/bin/env bats
# Unit tests for agents/fabric/fabric.sh
# Origin: T-931

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
FABRIC="$FRAMEWORK_ROOT/agents/fabric/fabric.sh"

# --- Help ---

@test "fabric help shows usage" {
    run "$FABRIC" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Fabric Agent"* ]]
    [[ "$output" == *"register"* ]]
    [[ "$output" == *"search"* ]]
    [[ "$output" == *"deps"* ]]
}

@test "fabric --help shows usage" {
    run "$FABRIC" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Fabric Agent"* ]]
}

@test "fabric no args shows help" {
    run "$FABRIC"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Fabric Agent"* ]]
}

# --- Overview ---

@test "fabric overview shows subsystems" {
    run "$FABRIC" overview
    [ "$status" -eq 0 ]
    [[ "$output" == *"System Topology"* ]] || [[ "$output" == *"subsystem"* ]] || [[ "$output" == *"components"* ]]
}

@test "fabric overview includes component count" {
    run "$FABRIC" overview
    [ "$status" -eq 0 ]
    # Should mention a number of components
    [[ "$output" =~ [0-9]+ ]]
}

# --- Search ---

@test "fabric search finds components" {
    run "$FABRIC" search "config"
    [ "$status" -eq 0 ]
    [[ "$output" == *"config"* ]]
}

@test "fabric search returns results for common term" {
    run "$FABRIC" search "watchtower"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

# --- Deps ---

@test "fabric deps shows dependencies for known file" {
    run "$FABRIC" deps lib/config.sh
    [ "$status" -eq 0 ]
}

@test "fabric deps handles unknown file gracefully" {
    run "$FABRIC" deps nonexistent/file.sh
    # Should not crash
    [[ "$status" -le 1 ]]
}

# --- Unknown command ---

@test "fabric unknown command shows help" {
    run "$FABRIC" nonexistent_command
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
    [[ "$output" == *"Fabric"* ]] || [[ "$output" == *"Usage"* ]] || [[ "$output" == *"Unknown"* ]]
}
