#!/usr/bin/env bats
# T-4807: `fw config get CONTEXT_WINDOW` printed the .framework.yaml value while
# FW_CONTEXT_WINDOW was set, so config get and the budget gate (fw_config) disagreed.
# Resolution order is CLI > FW_* env > .framework.yaml > default; get skipped the env tier.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TEST_DIR="$(mktemp -d "${BATS_TMPDIR:-/tmp}/t4807.XXXXXX")"
    export PROJECT_ROOT="$TEST_DIR"
    export FRAMEWORK_ROOT
    printf 'project_name: t4807\nCONTEXT_WINDOW: 975000\nPORT: 3001\n' > "$TEST_DIR/.framework.yaml"
    unset FW_CONTEXT_WINDOW FW_PORT FW_INCEPTION_COMMIT_LIMIT
}

teardown() {
    rm -rf "$TEST_DIR"
}

_cfg() {
    bash -c 'source "$FRAMEWORK_ROOT/lib/config.sh"; source "$FRAMEWORK_ROOT/lib/config-file.sh"; do_config "$@"' _ "$@"
}

@test "fw config get CONTEXT_WINDOW honours FW_CONTEXT_WINDOW (the field report)" {
    run env FW_CONTEXT_WINDOW=500000 "$FRAMEWORK_ROOT/bin/fw" config get CONTEXT_WINDOW
    [ "$status" -eq 0 ]
    [ "$output" = "500000" ]
}

@test "get agrees with fw_config for a registry key with env set" {
    export FW_CONTEXT_WINDOW=500000
    run _cfg get CONTEXT_WINDOW
    [ "$output" = "$(bash -c 'source "$FRAMEWORK_ROOT/lib/config.sh"; fw_config CONTEXT_WINDOW')" ]
    [ "$output" = "500000" ]
}

@test "env tier applies to every registry key, in any case" {
    export FW_PORT=4444
    run _cfg get port
    [ "$status" -eq 0 ]
    [ "$output" = "4444" ]
    # a registry key absent from the file still answers from env
    export FW_INCEPTION_COMMIT_LIMIT=6
    run _cfg get INCEPTION_COMMIT_LIMIT
    [ "$status" -eq 0 ]
    [ "$output" = "6" ]
}

@test "--file reads the file value, ignoring env" {
    export FW_CONTEXT_WINDOW=500000
    run _cfg get --file CONTEXT_WINDOW
    [ "$status" -eq 0 ]
    [ "$output" = "975000" ]
}

@test "without env, get still reads the file and exits 1 on a missing key" {
    run _cfg get CONTEXT_WINDOW
    [ "$output" = "975000" ]
    run _cfg get NONEXISTENT_KEY
    [ "$status" -eq 1 ]
}

@test "env tier does not apply to dotted or non-registry keys" {
    export FW_project_name=other
    run _cfg get project_name
    [ "$output" = "t4807" ]
}
