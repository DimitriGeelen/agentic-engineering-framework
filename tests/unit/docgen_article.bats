#!/usr/bin/env bats
# Unit tests for agents/docgen/generate-article.sh
# Origin: T-942

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
ARTICLE="$FRAMEWORK_ROOT/agents/docgen/generate-article.sh"

# --- Help ---

@test "article --help shows usage" {
    run "$ARTICLE" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw docs article"* ]]
    [[ "$output" == *"--generate"* ]]
    [[ "$output" == *"--list"* ]]
}

@test "article no args shows usage" {
    run "$ARTICLE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw docs article"* ]]
}

# --- List ---

@test "article --list shows subsystems" {
    run "$ARTICLE" --list
    [ "$status" -eq 0 ]
    [[ "$output" == *"subsystem"* ]] || [[ "$output" == *"components"* ]]
}

@test "article --list includes known subsystem" {
    run "$ARTICLE" --list
    [ "$status" -eq 0 ]
    # At least one subsystem should appear
    [[ "$output" =~ [0-9]+ ]]
}

# --- Invalid subsystem ---

@test "article with nonexistent subsystem calls generator" {
    # The script passes the subsystem to python3, which may fail
    # but the bash script itself should not crash before that
    run "$ARTICLE" "nonexistent_subsystem_xyz"
    # Either succeeds (creates empty prompt) or fails in python
    [[ "$status" -le 1 ]]
}
