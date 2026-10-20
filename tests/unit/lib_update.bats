#!/usr/bin/env bats
# Unit tests for lib/update.sh
#
# Tests do_update argument parsing and help

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/errors.sh"
    source "$FRAMEWORK_ROOT/lib/compat.sh"
    source "$FRAMEWORK_ROOT/lib/update.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "update: do_update --help shows usage" {
    run do_update --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw update"* ]]
    [[ "$output" == *"--check"* ]]
    [[ "$output" == *"--branch"* ]]
    [[ "$output" == *"--rollback"* ]]
}

@test "update: do_update rejects unknown option" {
    run do_update --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}

@test "update: do_update rejects unexpected argument" {
    run do_update something
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unexpected argument"* ]]
}

# ── T-3135: version ordering, not string inequality ──────────────────

@test "T-3135: _fw_version_cmp orders release versions numerically" {
    [ "$(_fw_version_cmp 1.8.9 1.8.14)" = "-1" ]
    [ "$(_fw_version_cmp 1.8.14 1.8.9)" = "1" ]
    [ "$(_fw_version_cmp 1.10.0 1.9.99)" = "1" ]
    [ "$(_fw_version_cmp v2.0.0 1.99.99)" = "1" ]
    [ "$(_fw_version_cmp 1.8.14 v1.8.14)" = "0" ]
}

@test "T-3135: a pre-release sorts below its release" {
    [ "$(_fw_version_cmp 1.8.15-be.1 1.8.15)" = "-1" ]
    [ "$(_fw_version_cmp 1.8.15 1.8.15-be.1)" = "1" ]
    [ "$(_fw_version_cmp 1.8.15-be.1 1.8.15-be.2)" = "-1" ]
    [ "$(_fw_version_cmp 1.8.15-be.1 1.8.14)" = "1" ]
}

@test "T-3135: unparseable versions compare as ?" {
    [ "$(_fw_version_cmp unknown 1.8.14)" = "?" ]
    [ "$(_fw_version_cmp 1.8.14 1.8)" = "?" ]
}

# Build a consumer whose vendored copy is at $1 and a local upstream at $2.
_t3135_fixture() {
    local upstream="$TEST_TEMP_DIR/upstream"
    mkdir -p "$upstream/bin" "$TEST_TEMP_DIR/.agentic-framework"
    echo "$2" > "$upstream/VERSION"
    git -C "$upstream" init -q -b master
    git -C "$upstream" -c user.email=t@t -c user.name=t add VERSION
    git -C "$upstream" -c user.email=t@t -c user.name=t commit -q -m init
    echo "$1" > "$TEST_TEMP_DIR/.agentic-framework/VERSION"
    printf 'upstream_repo: %s\n' "$upstream" > "$TEST_TEMP_DIR/.framework.yaml"
}

@test "T-3135: a vendored copy NEWER than upstream is not offered as an update" {
    _t3135_fixture 1.8.15 1.8.14
    run do_update --check
    [ "$status" -eq 0 ]
    [[ "$output" == *"newer than upstream"* ]]
    [[ "$output" != *"Update available"* ]]
}

@test "T-3135: a newer vendored copy is left untouched by a plain fw update" {
    _t3135_fixture 1.8.15 1.8.14
    do_vendor() { echo "VENDOR-CALLED"; }
    run do_update
    [ "$status" -eq 0 ]
    [[ "$output" != *"VENDOR-CALLED"* ]]
    [ "$(cat "$TEST_TEMP_DIR/.agentic-framework/VERSION")" = "1.8.15" ]
}

@test "T-3135: --allow-downgrade applies an older upstream explicitly" {
    _t3135_fixture 1.8.15 1.8.14
    do_vendor() { echo "VENDOR-CALLED"; }
    run do_update --allow-downgrade
    [ "$status" -eq 0 ]
    [[ "$output" == *"VENDOR-CALLED"* ]]
    [ "$(cat "$TEST_TEMP_DIR/.agentic-framework/VERSION")" = "1.8.14" ]
}

@test "T-3135 NEGATIVE CONTROL: a genuinely newer upstream is still offered" {
    _t3135_fixture 1.8.9 1.8.14
    run do_update --check
    [ "$status" -eq 0 ]
    [[ "$output" == *"Update available"* ]]
    [[ "$output" != *"newer than upstream"* ]]
}

@test "T-3135: unparseable vendored version keeps differs-means-update, with a warning" {
    _t3135_fixture unknown 1.8.14
    run do_update --check
    [ "$status" -eq 0 ]
    [[ "$output" == *"cannot order"* ]]
    [[ "$output" == *"Update available"* ]]
}
