#!/usr/bin/env bats
# T-1542: Bare-from-consumer fw upgrade guard
#
# When fw is invoked from a consumer's vendored copy
# (consumer/.agentic-framework/bin/fw upgrade with no target arg),
# FRAMEWORK_ROOT canonicalizes to consumer/.agentic-framework AND
# the target defaults to the consumer dir. do_vendor's late guard
# at step 4b fires AFTER steps 1-4a mutate state. The early guard
# in do_upgrade must detect and fail fast BEFORE any mutation.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export NO_COLOR=1
    export FW_VERSION="1.5.0"
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "upgrade: bare-from-consumer invocation fails fast with copy-pasteable command" {
    # Simulate consumer with vendored framework. FRAMEWORK_ROOT is set to the
    # vendored copy (as it would be when consumer/.agentic-framework/bin/fw
    # is the entry point).
    local consumer="$TEST_TEMP_DIR/consumer"
    mkdir -p "$consumer/.agentic-framework"
    echo "version: 1.5.0" > "$consumer/.framework.yaml"
    # The vendored copy needs to look enough like a framework root
    touch "$consumer/.agentic-framework/FRAMEWORK.md"

    # Override FRAMEWORK_ROOT for this test only (function-local)
    local saved_fw_root="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$consumer/.agentic-framework"

    run do_upgrade "$consumer"
    local status_code="$status"
    local out="$output"

    FRAMEWORK_ROOT="$saved_fw_root"

    [ "$status_code" -eq 1 ]
    [[ "$out" == *"invoked from inside the consumer's vendored framework"* ]]
    [[ "$out" == *"Source and target collapse"* ]]
    [[ "$out" == *"No changes made."* ]]
    [[ "$out" == *"bin/fw upgrade $consumer"* ]]
}

@test "upgrade: bare-from-consumer guard reports both paths" {
    local consumer="$TEST_TEMP_DIR/consumer2"
    mkdir -p "$consumer/.agentic-framework"
    echo "version: 1.5.0" > "$consumer/.framework.yaml"
    touch "$consumer/.agentic-framework/FRAMEWORK.md"

    local saved_fw_root="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$consumer/.agentic-framework"

    run do_upgrade "$consumer"
    local out="$output"

    FRAMEWORK_ROOT="$saved_fw_root"

    [[ "$out" == *"FRAMEWORK_ROOT:"* ]]
    [[ "$out" == *"target_dir:"* ]]
    [[ "$out" == *"Vendored copy:"* ]]
}

@test "upgrade: bare-from-consumer guard fires BEFORE any mutation (no self-vendor)" {
    # Self-vendor at lib/upgrade.sh would copy framework lib/*.sh into
    # .agentic-framework/lib/. With the guard, that copy must NOT happen.
    local consumer="$TEST_TEMP_DIR/consumer3"
    mkdir -p "$consumer/.agentic-framework/lib"
    echo "version: 1.5.0" > "$consumer/.framework.yaml"
    touch "$consumer/.agentic-framework/FRAMEWORK.md"

    # Pre-existing stale file inside vendored lib
    echo "STALE" > "$consumer/.agentic-framework/lib/upgrade.sh"
    local pre_md5
    pre_md5=$(md5sum "$consumer/.agentic-framework/lib/upgrade.sh" | cut -d' ' -f1)

    local saved_fw_root="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$consumer/.agentic-framework"

    run do_upgrade "$consumer"

    FRAMEWORK_ROOT="$saved_fw_root"

    local post_md5
    post_md5=$(md5sum "$consumer/.agentic-framework/lib/upgrade.sh" | cut -d' ' -f1)
    [ "$pre_md5" = "$post_md5" ]
}

@test "upgrade: normal invocation (framework repo → external consumer) still works" {
    # Sanity check: the guard doesn't false-positive on the normal case.
    local consumer="$TEST_TEMP_DIR/normal-consumer"
    mkdir -p "$consumer"
    echo "version: 1.4.0" > "$consumer/.framework.yaml"
    # FRAMEWORK_ROOT is the real framework, target is a separate dir, no
    # .agentic-framework inside target (or different canonical path)
    run do_upgrade "$consumer" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY RUN"* ]]
    [[ "$output" != *"invoked from inside the consumer's vendored framework"* ]]
}
