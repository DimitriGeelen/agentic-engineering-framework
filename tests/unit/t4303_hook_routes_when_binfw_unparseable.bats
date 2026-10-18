#!/usr/bin/env bats
# T-4303 / G-118: a bin/fw that does not parse must not take every hook down.
#
# Every Claude Code hook runs `bin/fw hook NAME`. bash parses bin/fw from the top, so
# an unclosed block anywhere in the file (T-4298 left one at line 1354) made every
# hook fail before the `hook)` branch ran. The fix routes `hook` through a fast path
# near the top of bin/fw that runs lib/hook-dispatch.sh when bin/fw does not parse.
#
# Each test copies bin/fw into a temp tree (never the repo) and appends an unclosed
# block to the copy, so bin/fw in that tree cannot parse. Without the fix, every
# `hook` call in that tree fails with "unexpected end of file" and the probe never runs.

setup() {
    TEST_TREE="$(mktemp -d)"
    mkdir -p "$TEST_TREE/bin" "$TEST_TREE/lib" "$TEST_TREE/agents/context" \
        "$TEST_TREE/proj/.tasks"
    touch "$TEST_TREE/FRAMEWORK.md"
    cp "$BATS_TEST_DIRNAME/../../lib/hook-dispatch.sh" "$TEST_TREE/lib/"
    cp "$BATS_TEST_DIRNAME/../../lib/hook-telemetry.sh" "$TEST_TREE/lib/"
    cat > "$TEST_TREE/agents/context/probe-hook.sh" <<'PROBE'
#!/bin/bash
echo "probe routed: $*"
[ "${1:-}" = "fail" ] && exit 2
exit 0
PROBE
    # Healthy copy of bin/fw, then a broken copy: an unclosed `if` injected just above the
    # main routing case, i.e. in the bulk and above the hook) branch. Appending at EOF would
    # not reproduce G-118: bash has already run the complete case block by then.
    cp "$BATS_TEST_DIRNAME/../../bin/fw" "$TEST_TREE/bin/fw.healthy"
    awk '/^# --- Main Command Routing ---$/ { print "if true; then"; print "    echo never-reached" } { print }' \
        "$TEST_TREE/bin/fw.healthy" > "$TEST_TREE/bin/fw.broken"
    cp "$TEST_TREE/bin/fw.broken" "$TEST_TREE/bin/fw"
    chmod +x "$TEST_TREE/bin/fw"
}

teardown() {
    [ -d "${TEST_TREE:-}" ] && rm -rf "$TEST_TREE"
}

@test "T-4303: healthy bin/fw still routes a hook (fast path falls through)" {
    cp "$TEST_TREE/bin/fw.healthy" "$TEST_TREE/bin/fw"
    cd "$TEST_TREE/proj"
    run env -u PROJECT_ROOT -u FRAMEWORK_ROOT CLAUDE_PROJECT_DIR="$TEST_TREE/proj" "$TEST_TREE/bin/fw" hook probe-hook one
    [ "$status" -eq 0 ]
    [[ "$output" == *"probe routed: one"* ]]
}

@test "T-4303: unparseable bin/fw still routes a hook (regression — fails without the fix)" {
    cd "$TEST_TREE/proj"
    run env -u PROJECT_ROOT -u FRAMEWORK_ROOT CLAUDE_PROJECT_DIR="$TEST_TREE/proj" "$TEST_TREE/bin/fw" hook probe-hook one
    [ "$status" -eq 0 ]
    [[ "$output" == *"probe routed: one"* ]]
}

@test "T-4303: unparseable bin/fw names bin/fw, says it does not parse, and gives the repair" {
    cd "$TEST_TREE/proj"
    run env -u PROJECT_ROOT -u FRAMEWORK_ROOT CLAUDE_PROJECT_DIR="$TEST_TREE/proj" "$TEST_TREE/bin/fw" hook probe-hook
    [[ "$output" == *"bin/fw"* ]]
    [[ "$output" == *"does not parse"* ]]
    [[ "$output" == *"bash -n bin/fw"* ]]
    [[ "$output" == *"git diff bin/fw"* ]]
}

@test "T-4303: unparseable bin/fw propagates the hook's exit code (exit 2 blocks, as before)" {
    cd "$TEST_TREE/proj"
    run env -u PROJECT_ROOT -u FRAMEWORK_ROOT CLAUDE_PROJECT_DIR="$TEST_TREE/proj" "$TEST_TREE/bin/fw" hook probe-hook fail
    [ "$status" -eq 2 ]
    [[ "$output" == *"probe routed: fail"* ]]
}

@test "T-4303: unparseable bin/fw degrades a missing hook to allow (exit 0)" {
    cd "$TEST_TREE/proj"
    run env -u PROJECT_ROOT -u FRAMEWORK_ROOT CLAUDE_PROJECT_DIR="$TEST_TREE/proj" "$TEST_TREE/bin/fw" hook no-such-hook
    [ "$status" -eq 0 ]
    [[ "$output" == *"Hook script not found"* ]]
}

@test "T-4303: the unparseable fast path is limited to fw hook (other verbs still fail loudly)" {
    cd "$TEST_TREE/proj"
    run env -u PROJECT_ROOT -u FRAMEWORK_ROOT CLAUDE_PROJECT_DIR="$TEST_TREE/proj" "$TEST_TREE/bin/fw" version
    [ "$status" -ne 0 ]
    [[ "$output" == *"unexpected end of file"* ]]
}
