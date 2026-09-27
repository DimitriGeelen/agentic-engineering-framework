#!/usr/bin/env bats
# T-2854 (D-377) — bin/claude-fw-router: the `claude-fw` entry point on PATH.
#
# Sibling of tests/unit/fw_router.bats / router_no_global_fallback.bats, same
# testing shape: stub the thing being routed to with a script that prints its
# own path, and assert on that path. Unlike bin/fw-router, claude-fw-router has
# no framework-only refusal to fall back to — a bare directory or a project
# with no claude-fw sibling both degrade to plain `claude`, they don't error.

bats_require_minimum_version 1.5.0

load ../test_helper

ROUTER="$FRAMEWORK_ROOT/bin/claude-fw-router"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export HOME="$TEST_TEMP_DIR/home"
    mkdir -p "$HOME"
    unset FW_ROUTED_FROM

    # Stand-in `claude` on PATH so the no-project / no-wrapper fallback has
    # something deterministic to exec instead of a real Claude Code launch.
    STUB_BIN="$TEST_TEMP_DIR/stubpath"
    mkdir -p "$STUB_BIN"
    printf '#!/bin/bash\necho "PLAIN_CLAUDE ARGS=%s"\n' '$*' > "$STUB_BIN/claude"
    chmod +x "$STUB_BIN/claude"
    export PATH="$STUB_BIN:$PATH"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

# _stub_project <project_dir> <fw_rel> <claude_fw_rel> — builds a minimal
# project shape: a fake bin/fw (existence only — claude-fw-router only checks
# it as the project-detection anchor) plus a fake claude-fw that reports which
# copy it is.
_stub_vendored_project() {
    local proj="$1"
    mkdir -p "$proj/.agentic-framework/bin"
    : > "$proj/.agentic-framework/FRAMEWORK.md"
    printf '#!/bin/sh\n' > "$proj/.agentic-framework/bin/fw"
    chmod +x "$proj/.agentic-framework/bin/fw"
    cat > "$proj/.agentic-framework/bin/claude-fw" <<'CLI_EOF'
#!/bin/bash
echo "WRAPPER=$0"
echo "ARGS=$*"
CLI_EOF
    chmod +x "$proj/.agentic-framework/bin/claude-fw"
}

@test "routes to a vendored consumer's own claude-fw" {
    local proj="$TEST_TEMP_DIR/consumer"
    _stub_vendored_project "$proj"
    cd "$proj"
    run bash "$ROUTER" --no-restart
    [ "$status" -eq 0 ]
    [[ "$output" == *"WRAPPER=$proj/.agentic-framework/bin/claude-fw"* ]]
    [[ "$output" == *"ARGS=--no-restart"* ]]
}

@test "walking up from a nested subdirectory still finds the project's claude-fw" {
    local proj="$TEST_TEMP_DIR/consumer"
    _stub_vendored_project "$proj"
    mkdir -p "$proj/src/deep"
    cd "$proj/src/deep"
    run bash "$ROUTER"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WRAPPER=$proj/.agentic-framework/bin/claude-fw"* ]]
}

@test "the framework repo routes to its own bin/claude-fw, not its self-vendored copy" {
    local repo="$TEST_TEMP_DIR/framework"
    mkdir -p "$repo/bin"
    : > "$repo/FRAMEWORK.md"
    printf '#!/bin/sh\n' > "$repo/bin/fw"
    chmod +x "$repo/bin/fw"
    cat > "$repo/bin/claude-fw" <<'CLI_EOF'
#!/bin/bash
echo "WRAPPER=$0"
CLI_EOF
    chmod +x "$repo/bin/claude-fw"
    _stub_vendored_project "$repo/.agentic-framework"
    cd "$repo"
    run bash "$ROUTER"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WRAPPER=$repo/bin/claude-fw"* ]]
}

@test "no project found: falls back to plain claude, announced on stderr" {
    local bare="$TEST_TEMP_DIR/bare"
    mkdir -p "$bare"
    cd "$bare"
    bash "$ROUTER" --no-restart >"$TEST_TEMP_DIR/out" 2>"$TEST_TEMP_DIR/err"
    grep -q "PLAIN_CLAUDE" "$TEST_TEMP_DIR/out"
    grep -q "no framework project found" "$TEST_TEMP_DIR/err"
}

@test "project found but no claude-fw sibling: falls back to plain claude" {
    local proj="$TEST_TEMP_DIR/half-vendored"
    mkdir -p "$proj/.agentic-framework/bin"
    : > "$proj/.agentic-framework/FRAMEWORK.md"
    printf '#!/bin/sh\n' > "$proj/.agentic-framework/bin/fw"
    chmod +x "$proj/.agentic-framework/bin/fw"
    # Deliberately no claude-fw in this vendor.
    cd "$proj"
    bash "$ROUTER" --no-restart >"$TEST_TEMP_DIR/out" 2>"$TEST_TEMP_DIR/err"
    grep -q "PLAIN_CLAUDE" "$TEST_TEMP_DIR/out"
    grep -q "no wrapper found" "$TEST_TEMP_DIR/err"
}

@test "exports FW_ROUTED_FROM when a project is found" {
    local proj="$TEST_TEMP_DIR/consumer"
    _stub_vendored_project "$proj"
    cat > "$proj/.agentic-framework/bin/claude-fw" <<'CLI_EOF'
#!/bin/bash
echo "ROUTED_FROM=${FW_ROUTED_FROM:-}"
CLI_EOF
    chmod +x "$proj/.agentic-framework/bin/claude-fw"
    cd "$proj"
    run bash "$ROUTER"
    [[ "$output" == *"ROUTED_FROM=$proj"* ]]
}

@test "an incomplete vendor mid-init is not routed to, falls back to plain claude" {
    local proj="$TEST_TEMP_DIR/partial"
    mkdir -p "$proj/.agentic-framework/bin"
    printf '#!/bin/sh\n' > "$proj/.agentic-framework/bin/fw"
    chmod +x "$proj/.agentic-framework/bin/fw"
    # No FRAMEWORK.md — mid-init, per T-2805/T-2811 parity with bin/fw-router.
    cd "$proj"
    bash "$ROUTER" >"$TEST_TEMP_DIR/out" 2>"$TEST_TEMP_DIR/err"
    grep -q "PLAIN_CLAUDE" "$TEST_TEMP_DIR/out"
    grep -q "no framework project found" "$TEST_TEMP_DIR/err"
}
