#!/usr/bin/env bats
# Unit tests for agents/docgen/generate-component.sh
# Origin: T-942

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
COMPONENT="$FRAMEWORK_ROOT/agents/docgen/generate-component.sh"

# --- Help ---

@test "component no args shows usage" {
    run "$COMPONENT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw docs"* ]]
    [[ "$output" == *"--all"* ]]
}

# --- Single card ---

@test "component generates doc for known card" {
    # Pick first available card
    card=$(ls "$FRAMEWORK_ROOT/.fabric/components/"*.yaml 2>/dev/null | head -1)
    [ -n "$card" ] || skip "No fabric cards found"
    run "$COMPONENT" "$card"
    [ "$status" -eq 0 ]
}

@test "component handles card by name without path" {
    # Try with just the card filename
    card=$(ls "$FRAMEWORK_ROOT/.fabric/components/"*.yaml 2>/dev/null | head -1)
    [ -n "$card" ] || skip "No fabric cards found"
    basename_card=$(basename "$card")
    run "$COMPONENT" "$basename_card"
    [ "$status" -eq 0 ]
}

@test "component handles card by name without extension" {
    card=$(ls "$FRAMEWORK_ROOT/.fabric/components/"*.yaml 2>/dev/null | head -1)
    [ -n "$card" ] || skip "No fabric cards found"
    basename_noext=$(basename "$card" .yaml)
    run "$COMPONENT" "$basename_noext"
    [ "$status" -eq 0 ]
}

# --- Card not found ---

@test "component fails for nonexistent card" {
    run "$COMPONENT" "nonexistent_card_xyz"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not found"* ]]
}

# --- All ---

@test "component --all starts generation" {
    # --all generates for all components (~99); just verify it starts correctly
    # Full run takes too long for unit test, so we check output begins properly
    run timeout 10 "$COMPONENT" --all
    # timeout exit code 124 means it ran but was killed (expected for large set)
    # exit 0 means it completed (fast enough)
    [[ "$status" -eq 0 ]] || [[ "$status" -eq 124 ]]
    [[ "$output" == *"Generating"* ]] || [[ "$output" == *"Generated"* ]]
}
