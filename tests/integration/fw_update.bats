#!/usr/bin/env bats
# Integration tests for fw update subcommand

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "fw update --help: shows usage" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' update --help"
    [ "$status" -eq 0 ]
    [[ "$output" == *"update"* ]]
    [[ "$output" == *"--check"* ]] || [[ "$output" == *"--branch"* ]] || [[ "$output" == *"--rollback"* ]]
}

@test "fw update --check: shows version info" {
    # T-4601: fw update only serves a vendored project (T-2800/D-377: no global
    # fallback), so the fixture needs a vendored copy and an upstream to compare
    # against. A local upstream repo keeps it hermetic (no network).
    local up="$TEST_TEMP_DIR/upstream"
    git init -q -b master "$up"
    echo "9.9.9" > "$up/VERSION"
    git -C "$up" add VERSION
    git -C "$up" -c user.email=t@t -c user.name=t commit -q -m "upstream release"
    mkdir -p "$PROJECT_ROOT/.agentic-framework"
    echo "1.0.0" > "$PROJECT_ROOT/.agentic-framework/VERSION"
    echo "upstream_repo: $up" >> "$PROJECT_ROOT/.framework.yaml"

    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' update --check 2>&1"
    # The refusal must not be what we matched (the old loose pattern hit "update").
    [[ "$output" != *"No vendored framework"* ]]
    [ "$status" -eq 0 ]
    [[ "$output" == *"Current:   v1.0.0"* ]]
    [[ "$output" == *"Update available:"*"v1.0.0"*"v9.9.9"* ]]
    # --check applies nothing.
    [ "$(cat "$PROJECT_ROOT/.agentic-framework/VERSION")" = "1.0.0" ]
}
