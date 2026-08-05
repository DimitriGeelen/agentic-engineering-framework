#!/usr/bin/env bats
# T-2793 — bin/fw-router: the `fw` entry point on PATH.
#
# The router's whole job is deciding WHICH fw runs. So these tests stub the CLI
# with a script that prints its own path, and assert on that path. Identity is
# the property under test; asserting on framework behaviour instead would be the
# same wrong-object mistake the router exists to fix (a consumer ran the global
# CLI for months while every version line it printed was individually true).

bats_require_minimum_version 1.5.0

load ../test_helper

ROUTER="$FRAMEWORK_ROOT/bin/fw-router"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    # Point HOME at an empty dir so a real ~/.agentic-framework on the host can
    # never satisfy the bootstrap fallback silently.
    export HOME="$TEST_TEMP_DIR/home"
    mkdir -p "$HOME"
    unset FW_GLOBAL_ROOT FW_ROUTED_FROM FW_ROUTER_TARGET
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

# _stub_cli <path> — a fake framework CLI that reports which copy it is.
#
# T-2811: also writes the FRAMEWORK.md that makes the copy COMPLETE. T-2805 made
# that file load-bearing (bin/fw-router:96): a vendored .agentic-framework with an
# executable bin/fw but no FRAMEWORK.md is an interrupted init, and the router
# refuses it with 127 rather than routing there. These fixtures predated that and
# built a project shape that cannot exist, so 7 of 12 tests were asserting against
# a refusal — red for a year of router changes without ever being about the router.
#
# The path arithmetic is "two levels up from the CLI", which lands correctly for
# BOTH layouts the helper is called with, because it is the same walk the router
# itself does:
#   <proj>/.agentic-framework/bin/fw  ->  <proj>/.agentic-framework/FRAMEWORK.md
#   <repo>/bin/fw                     ->  <repo>/FRAMEWORK.md
_stub_cli() {
    mkdir -p "$(dirname "$1")"
    : > "$(dirname "$(dirname "$1")")/FRAMEWORK.md"
    cat > "$1" <<'EOF'
#!/bin/bash
echo "CLI=$0"
echo "ROUTED_FROM=${FW_ROUTED_FROM:-}"
echo "ARGS=$*"
EOF
    chmod +x "$1"
}

@test "routes to a vendored consumer's own CLI" {
    local proj="$TEST_TEMP_DIR/consumer"
    _stub_cli "$proj/.agentic-framework/bin/fw"
    cd "$proj"
    run bash "$ROUTER" doctor --json
    [ "$status" -eq 0 ]
    [[ "$output" == *"CLI=$proj/.agentic-framework/bin/fw"* ]]
    [[ "$output" == *"ARGS=doctor --json"* ]]
}

@test "walks up from a nested subdirectory" {
    local proj="$TEST_TEMP_DIR/consumer"
    _stub_cli "$proj/.agentic-framework/bin/fw"
    mkdir -p "$proj/src/deep/deeper"
    cd "$proj/src/deep/deeper"
    run bash "$ROUTER" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"CLI=$proj/.agentic-framework/bin/fw"* ]]
}

@test "the nearest project wins over an outer one" {
    local outer="$TEST_TEMP_DIR/outer" inner="$TEST_TEMP_DIR/outer/inner"
    _stub_cli "$outer/.agentic-framework/bin/fw"
    _stub_cli "$inner/.agentic-framework/bin/fw"
    cd "$inner"
    run bash "$ROUTER" status
    [[ "$output" == *"CLI=$inner/.agentic-framework/bin/fw"* ]]
    [[ "$output" != *"CLI=$outer/.agentic-framework/bin/fw"* ]]
}

@test "a framework repo routes to its own bin/fw, not its self-vendored copy" {
    local repo="$TEST_TEMP_DIR/framework"
    mkdir -p "$repo"; : > "$repo/FRAMEWORK.md"
    _stub_cli "$repo/bin/fw"
    _stub_cli "$repo/.agentic-framework/bin/fw"
    cd "$repo"
    run bash "$ROUTER" status
    [[ "$output" == *"CLI=$repo/bin/fw"* ]]
}

@test "exports FW_ROUTED_FROM so the routing decision is observable" {
    local proj="$TEST_TEMP_DIR/consumer"
    _stub_cli "$proj/.agentic-framework/bin/fw"
    cd "$proj"
    run bash "$ROUTER" status
    [[ "$output" == *"ROUTED_FROM=$proj"* ]]
}

@test "bootstrap: falls back to the global install when no project is found" {
    local glob="$TEST_TEMP_DIR/global" bare="$TEST_TEMP_DIR/bare"
    _stub_cli "$glob/bin/fw"
    mkdir -p "$bare"
    cd "$bare"
    FW_GLOBAL_ROOT="$glob" run bash "$ROUTER" init
    [ "$status" -eq 0 ]
    [[ "$output" == *"CLI=$glob/bin/fw"* ]]
}

@test "bootstrap fallback is announced on stderr, never silent" {
    local glob="$TEST_TEMP_DIR/global" bare="$TEST_TEMP_DIR/bare"
    _stub_cli "$glob/bin/fw"
    mkdir -p "$bare"
    cd "$bare"
    FW_GLOBAL_ROOT="$glob" bash "$ROUTER" init >"$TEST_TEMP_DIR/out" 2>"$TEST_TEMP_DIR/err"
    grep -q "using global install" "$TEST_TEMP_DIR/err"
    # …and stays OFF stdout: `fw <cmd> --json` from a non-project directory must
    # remain machine-parseable (the T-2769 / T-2771 stdout-purity contract).
    ! grep -q "using global install" "$TEST_TEMP_DIR/out"
}

@test "no project and no global install fails loudly and actionably" {
    local bare="$TEST_TEMP_DIR/bare"
    mkdir -p "$bare"
    cd "$bare"
    FW_GLOBAL_ROOT="$TEST_TEMP_DIR/nope" run -127 bash "$ROUTER" doctor
    [[ "$output" == *"no framework found"* ]]
    [[ "$output" == *"fw init"* ]]
}

@test "refuses to exec itself (routing loop)" {
    local proj="$TEST_TEMP_DIR/looper"
    mkdir -p "$proj/.agentic-framework/bin"
    # T-2811: complete the copy (see _stub_cli). Without FRAMEWORK.md the router
    # dies at the incompleteness check with 127 and never reaches the loop check,
    # so this test asserted 126 against a message about interrupted inits.
    : > "$proj/.agentic-framework/FRAMEWORK.md"
    cp "$ROUTER" "$proj/.agentic-framework/bin/fw"
    cd "$proj"
    # 126 ("found, cannot execute"), not 127 — a loop is not a missing install.
    run -126 bash "$proj/.agentic-framework/bin/fw" status
    [[ "$output" == *"routing loop"* ]]
    # T-2794: the primary remedy must not assume the reader knows this location
    # is a git clone — lead with the installer, which self-heals unconditionally.
    [[ "$output" == *"install.sh"* ]]
    [[ "$output" == *"git checkout HEAD -- bin/fw"* ]]
}

@test "the walk-up stops before the filesystem root" {
    # Parity with lib/paths.sh and (since T-2793) lib/hook_paths.py: "/" is never
    # a project. Non-vacuous on any host carrying a stray /.agentic-framework;
    # on a clean host it pins the contract without being able to fail.
    local glob="$TEST_TEMP_DIR/global"
    _stub_cli "$glob/bin/fw"
    cd /tmp
    FW_GLOBAL_ROOT="$glob" run bash "$ROUTER" status
    [[ "$output" == *"CLI=$glob/bin/fw"* ]]
}

@test "passes arguments through unchanged, including quoted whitespace" {
    local proj="$TEST_TEMP_DIR/consumer"
    _stub_cli "$proj/.agentic-framework/bin/fw"
    cd "$proj"
    run bash "$ROUTER" work-on "a task with spaces" --type build
    [[ "$output" == *"ARGS=work-on a task with spaces --type build"* ]]
}

@test "propagates the CLI's exit code" {
    local proj="$TEST_TEMP_DIR/consumer"
    mkdir -p "$proj/.agentic-framework/bin"
    # T-2811: this test builds its stub inline rather than via _stub_cli, so it
    # needs the completeness marker of its own. Without it the router refuses at
    # 127 and the 42 never gets a chance to propagate.
    : > "$proj/.agentic-framework/FRAMEWORK.md"
    printf '#!/bin/bash\nexit 42\n' > "$proj/.agentic-framework/bin/fw"
    chmod +x "$proj/.agentic-framework/bin/fw"
    cd "$proj"
    run bash "$ROUTER" audit
    [ "$status" -eq 42 ]
}
