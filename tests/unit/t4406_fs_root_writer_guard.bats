#!/usr/bin/env bats
# T-4406: writers that join a project root into a path must refuse an empty or
# `/` root. Debris found at the filesystem root — /policy (value-drivers.yaml +
# bvp-scoring-rubric.md, a framework-template copy) and empty /episodic and
# /working — is what `fw bvp driver --init` / `fw init` / `fw upgrade` and
# context.sh's ensure_context_dirs write when their root is `/` or empty.
#
# Nothing here ever runs a writer against the real `/`: a regression would
# write there. The behavioural legs use an EMPTY root with cwd inside the
# sandbox (where an unguarded writer lands in the sandbox, so red is safe), and
# the `/` legs go through the shared predicate plus a static pin that each
# writer calls it.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t4406-XXXXXX)"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

_paths() {
    # Source paths.sh in a sandboxed subshell context.
    PROJECT_ROOT="$TEST_TEMP_DIR" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash -c 'source "$FRAMEWORK_ROOT/lib/paths.sh" >/dev/null 2>&1; fw_refuse_fs_root "$@"' _ "$@"
}

@test "T-4406: fw_refuse_fs_root refuses empty, /, // and a path resolving to /" {
    run _paths "PROJECT_ROOT" ""
    [ "$status" -ne 0 ]
    [[ "$output" == *"PROJECT_ROOT"* ]]
    [[ "$output" == *"filesystem root"* ]]
    run _paths "PROJECT_ROOT" "/"
    [ "$status" -ne 0 ]
    run _paths "PROJECT_ROOT" "//"
    [ "$status" -ne 0 ]
    run _paths "CONTEXT_DIR" "/tmp/.."
    [ "$status" -ne 0 ]
}

@test "T-4406: fw_refuse_fs_root accepts a real directory and a not-yet-existing one" {
    run _paths "PROJECT_ROOT" "$TEST_TEMP_DIR"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run _paths "CONTEXT_DIR" "$TEST_TEMP_DIR/not-yet/.context"
    [ "$status" -eq 0 ]
}

@test "T-4406: fw bvp driver --init with PROJECT_ROOT=/ refuses before anything else" {
    # An empty PROJECT_ROOT is already refused by bvp.sh's `:?` guard, so `/` is
    # the reachable case. Safety: FRAMEWORK_ROOT is an EMPTY sandbox, so even an
    # unguarded writer stops at "framework template not found" before writing.
    # The guard must fire first, and say why.
    local lib="$FRAMEWORK_ROOT/lib/bvp.sh"
    mkdir -p "$TEST_TEMP_DIR/fwroot"
    run env PROJECT_ROOT="/" FRAMEWORK_ROOT="$TEST_TEMP_DIR/fwroot" \
        bash -c 'source "$1"; bvp_dispatch driver --init' _ "$lib" 2>&1
    [ "$status" -ne 0 ]
    [[ "$output" == *"filesystem root"* ]]
    [[ "$output" != *"template not found"* ]]
}

@test "T-4406: fw bvp driver --init still bootstraps a real project root" {
    mkdir -p "$TEST_TEMP_DIR/proj"
    run env PROJECT_ROOT="$TEST_TEMP_DIR/proj" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash -c 'source "$FRAMEWORK_ROOT/lib/bvp.sh"; bvp_dispatch driver --init' 2>&1
    [ "$status" -eq 0 ]
    [ -f "$TEST_TEMP_DIR/proj/policy/value-drivers.yaml" ]
    [ -f "$TEST_TEMP_DIR/proj/policy/bvp-scoring-rubric.md" ]
}

@test "T-4406: every root-joining writer calls the guard before it writes" {
    # context.sh: the guard sits inside ensure_context_dirs, before the mkdir.
    run grep -A3 '^ensure_context_dirs()' "$FRAMEWORK_ROOT/agents/context/context.sh"
    [[ "$output" == *'fw_refuse_fs_root CONTEXT_DIR "$CONTEXT_DIR"'* ]]
    # init.sh / upgrade.sh: the guard follows the absolute-path resolution.
    grep -q 'fw_refuse_fs_root "fw init target" "$target_dir"' "$FRAMEWORK_ROOT/lib/init.sh"
    grep -q 'fw_refuse_fs_root "fw upgrade target" "$target_dir"' "$FRAMEWORK_ROOT/lib/upgrade.sh"
    # bvp.sh: the python writer carries its own copy of the test.
    grep -q '_refuse_fs_root(PROJECT_ROOT_RAW' "$FRAMEWORK_ROOT/lib/bvp.sh"
}
