#!/usr/bin/env bats
# T-4335 / G-118: the degraded-hook repair line must name the file that does not parse.
#
# T-4303's fast path printed "repair (from the framework repo root): bash -n bin/fw".
# In a consumer the broken file is the vendored .agentic-framework/bin/fw, so the line
# pointed at a file that does not exist there (832 T-1204). The line now names the real
# path, relative to PROJECT_ROOT when the file is inside it, absolute otherwise.

# Build a framework tree at $1 whose bin/fw does not parse (same injection as t4303).
_make_broken_fw_tree() {
    local root="$1"
    mkdir -p "$root/bin" "$root/lib" "$root/agents/context"
    touch "$root/FRAMEWORK.md"
    cp "$BATS_TEST_DIRNAME/../../lib/hook-dispatch.sh" "$root/lib/"
    cp "$BATS_TEST_DIRNAME/../../lib/hook-telemetry.sh" "$root/lib/"
    printf '#!/bin/bash\necho "probe routed: $*"\nexit 0\n' > "$root/agents/context/probe-hook.sh"
    awk '/^# --- Main Command Routing ---$/ { print "if true; then"; print "    echo never-reached" } { print }' \
        "$BATS_TEST_DIRNAME/../../bin/fw" > "$root/bin/fw"
    chmod +x "$root/bin/fw"
}

setup() {
    TEST_TREE="$(mktemp -d)"
}

teardown() {
    [ -d "${TEST_TREE:-}" ] && rm -rf "$TEST_TREE"
}

@test "T-4335: consumer — repair line names .agentic-framework/bin/fw from the project root" {
    local proj="$TEST_TREE/consumer"
    mkdir -p "$proj/.tasks"
    touch "$proj/.framework.yaml"
    _make_broken_fw_tree "$proj/.agentic-framework"
    touch "$proj/.agentic-framework/.fw-not-a-project"
    cd "$proj"
    run env -u PROJECT_ROOT -u FRAMEWORK_ROOT CLAUDE_PROJECT_DIR="$proj" "$proj/.agentic-framework/bin/fw" hook probe-hook one
    [ "$status" -eq 0 ]
    [[ "$output" == *"probe routed: one"* ]]
    [[ "$output" == *"bash -n .agentic-framework/bin/fw"* ]]
    [[ "$output" == *"git diff .agentic-framework/bin/fw"* ]]
    [[ "$output" == *"(from $proj)"* ]]
    [[ "$output" != *"framework repo root"* ]]
}

@test "T-4335: framework repo — repair line names bin/fw from the repo root" {
    local fw="$TEST_TREE/framework"
    _make_broken_fw_tree "$fw"
    mkdir -p "$fw/.tasks"
    cd "$fw"
    run env -u PROJECT_ROOT -u FRAMEWORK_ROOT CLAUDE_PROJECT_DIR="$fw" "$fw/bin/fw" hook probe-hook one
    [ "$status" -eq 0 ]
    [[ "$output" == *"bash -n bin/fw "* ]]
    [[ "$output" == *"git diff bin/fw "* ]]
    [[ "$output" == *"(from $fw)"* ]]
}

@test "T-4335: bin/fw outside the project — repair line uses the absolute path" {
    local fw="$TEST_TREE/shared-fw" proj="$TEST_TREE/proj"
    _make_broken_fw_tree "$fw"
    mkdir -p "$proj/.tasks"
    cd "$proj"
    run env -u PROJECT_ROOT -u FRAMEWORK_ROOT CLAUDE_PROJECT_DIR="$proj" "$fw/bin/fw" hook probe-hook one
    [ "$status" -eq 0 ]
    [[ "$output" == *"bash -n $fw/bin/fw"* ]]
    [[ "$output" == *"git -C $fw diff bin/fw"* ]]
}
