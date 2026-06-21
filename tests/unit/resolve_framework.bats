#!/usr/bin/env bats
# T-1356 (T-1346-B1): Unit tests for bin/fw resolve_framework rule order.
#
# The resolver must pick the right FRAMEWORK_ROOT in three scenarios:
#   (a) framework-repo self-invocation  → resolves to the repo itself
#   (b) direct vendored invocation      → resolves to .agentic-framework
#   (c) global-shim in vendored consumer → resolves to vendored (THE LEAK FIX)
#
# Setup uses light "framework" fixtures: a FRAMEWORK.md + bin/fw copy + agents/ dir.

load ../test_helper

# T-2454/OBS-083: these tests exercise bin/fw's *filesystem* resolution (cwd +
# fixture layout), so the fixture fw must NOT inherit the ambient resolver env.
# test_helper.bash exports FRAMEWORK_ROOT (and a session may export PROJECT_ROOT
# / CLAUDE_PROJECT_DIR); bin/fw honours all three as explicit overrides, which
# pins every fixture to /opt/999 (Mode: global) and makes all 3 assertions fail.
# Strip them on each invocation — NOT at the bats level (test_helper re-derives
# and re-exports FRAMEWORK_ROOT, so an outer `env -u` is undone before the test).
FW_HERMETIC="env -u FRAMEWORK_ROOT -u PROJECT_ROOT -u CLAUDE_PROJECT_DIR"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    # Real fw binary under test
    FW_SCRIPT="$FRAMEWORK_ROOT/bin/fw"
    [ -x "$FW_SCRIPT" ]
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Build a minimal framework fixture at $1 (creates FRAMEWORK.md + agents/ + bin/fw symlink to real fw).
make_framework_fixture() {
    local dir="$1"
    mkdir -p "$dir/agents" "$dir/bin"
    touch "$dir/FRAMEWORK.md"
    ln -s "$FW_SCRIPT" "$dir/bin/fw"
}

# Build a consumer project at $1 with .tasks/ and (optionally) a vendored framework.
make_consumer() {
    local dir="$1"
    local with_vendored="${2:-0}"
    mkdir -p "$dir/.tasks/active"
    if [ "$with_vendored" = "1" ]; then
        make_framework_fixture "$dir/.agentic-framework"
    fi
}

@test "resolve_framework: framework-repo self-invocation resolves to repo" {
    # For this test we need a fixture whose bin/fw is a REAL file (not symlink),
    # so readlink -f resolves within the fixture. Copy the fw binary + minimal deps.
    local repo="$TEST_TEMP_DIR/fw-repo"
    mkdir -p "$repo/bin" "$repo/agents"
    cp "$FW_SCRIPT" "$repo/bin/fw"
    touch "$repo/FRAMEWORK.md"
    # Symlink lib/ (fw sources from it at runtime) and provide VERSION
    ln -s "$FRAMEWORK_ROOT/lib" "$repo/lib"
    cp "$FRAMEWORK_ROOT/VERSION" "$repo/VERSION" 2>/dev/null || echo "0.0.0" > "$repo/VERSION"
    # Also give the repo its own nested .agentic-framework to prove self wins
    make_framework_fixture "$repo/.agentic-framework"
    # Empty .framework.yaml — tests show_version tolerates no-version (T-1362)
    touch "$repo/.framework.yaml"  # empty — tests show_version tolerates no-version (T-1362)

    cd "$repo"
    run $FW_HERMETIC "$repo/bin/fw" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -qE "Framework:[[:space:]]+$repo[[:space:]]*$"
}

@test "resolve_framework: direct vendored invocation resolves to vendored" {
    local consumer="$TEST_TEMP_DIR/consumer-direct"
    make_consumer "$consumer" 1

    cd "$consumer"
    run $FW_HERMETIC "$consumer/.agentic-framework/bin/fw" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -qE "Framework:[[:space:]]+$consumer/.agentic-framework[[:space:]]*$"
}

@test "resolve_framework: global-shim in vendored consumer resolves to vendored (T-1346 leak fix)" {
    # Simulate the global install
    local global="$TEST_TEMP_DIR/global-fw"
    make_framework_fixture "$global"

    # Simulate the shim at ~/.local/bin that points at global
    local shim_dir="$TEST_TEMP_DIR/shim"
    mkdir -p "$shim_dir"
    ln -s "$global/bin/fw" "$shim_dir/fw"

    # Consumer with its own vendored framework
    local consumer="$TEST_TEMP_DIR/consumer-shim"
    make_consumer "$consumer" 1

    cd "$consumer"
    # Invoke via the shim — readlink -f will resolve to $global/bin/fw.
    # Pre-fix: FRAMEWORK resolves to $global. Post-fix: resolves to $consumer/.agentic-framework.
    run $FW_HERMETIC "$shim_dir/fw" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -qE "Framework:[[:space:]]+$consumer/.agentic-framework[[:space:]]*$"
    # Negative assertion: must NOT be the global
    ! echo "$output" | grep -qE "Framework:[[:space:]]+$global[[:space:]]*$"
}
