#!/usr/bin/env bats
# T-2450 / F3: bin/fw _derive_version must resolve symlinks before deriving
# fw_dir. The global shim ~/.local/bin/fw is a SYMLINK to the framework's
# bin/fw; the unresolved BASH_SOURCE[0] used to make fw_dir point at the
# symlink's parent (~/.local — no .git, no VERSION), so version derivation
# fell through to "dev" and `fw --version` reported `vdev` (T-2441 dogfood F3).
#
# These tests invoke fw via a symlink in a bare directory (no .git, no VERSION)
# and assert the reported version matches the direct invocation — i.e. never
# degrades to `dev`/`vdev` purely because of how fw was invoked.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    FW="$FRAMEWORK_ROOT/bin/fw"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "F3: direct invocation reports a real version (not dev)" {
    run "$FW" --version
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" =~ ^fw\ v[0-9] ]]
    [[ "${lines[0]}" != *"vdev"* ]]
}

@test "F3: invocation via symlink in a bare dir does NOT report vdev" {
    # Bare dir: no .git, no VERSION — models ~/.local/bin holding the shim.
    mkdir -p "$TEST_TEMP_DIR/bare/bin"
    ln -sf "$FW" "$TEST_TEMP_DIR/bare/bin/fw"
    run "$TEST_TEMP_DIR/bare/bin/fw" --version
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" =~ ^fw\ v[0-9] ]]
    [[ "${lines[0]}" != *"vdev"* ]]
}

@test "F3: symlink and direct invocation report the SAME version" {
    mkdir -p "$TEST_TEMP_DIR/bare/bin"
    ln -sf "$FW" "$TEST_TEMP_DIR/bare/bin/fw"
    direct=$("$FW" --version 2>/dev/null | head -1)
    via_link=$("$TEST_TEMP_DIR/bare/bin/fw" --version 2>/dev/null | head -1)
    [ "$direct" = "$via_link" ]
}

@test "F3: chained symlink resolves through to the real fw_dir" {
    # symlink → symlink → real bin/fw; readlink -f follows the whole chain.
    mkdir -p "$TEST_TEMP_DIR/a/bin" "$TEST_TEMP_DIR/b/bin"
    ln -sf "$FW" "$TEST_TEMP_DIR/a/bin/fw"
    ln -sf "$TEST_TEMP_DIR/a/bin/fw" "$TEST_TEMP_DIR/b/bin/fw"
    run "$TEST_TEMP_DIR/b/bin/fw" --version
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" != *"vdev"* ]]
}
