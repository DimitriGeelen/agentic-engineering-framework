#!/usr/bin/env bats
# Unit tests for lib/ask.sh (fw ask)
# Origin: T-945

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
ASK="$FRAMEWORK_ROOT/lib/ask.sh"

@test "ask --help shows usage" {
    run "$ASK" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw ask"* ]]
    [[ "$output" == *"question"* ]]
}

@test "ask -h shows usage" {
    run "$ASK" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw ask"* ]]
}

@test "ask no args shows usage" {
    run "$ASK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "ask help lists options" {
    run "$ASK" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--json"* ]]
    [[ "$output" == *"--concise"* ]]
    [[ "$output" == *"--think"* ]]
}

@test "ask help shows examples" {
    run "$ASK" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Examples"* ]]
}
