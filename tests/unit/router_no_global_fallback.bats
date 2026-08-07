#!/usr/bin/env bats
# T-2854 (D-377) — bin/fw-router carries NO global-install fallback.
#
# Before this task, a pre-T-2800 residue global (~/.agentic-framework or, on
# this host, a stray /.agentic-framework) stayed alive AND authoritative: the
# router's own refusal message already asserted "there is no global install to
# fall back on by design", and it was only ever printed when no global
# happened to exist. Where one did, code twenty lines above ran it — the
# contradiction that surfaced as T-2853 (fw update misrouting).
#
# This file pins the three properties the AC calls out by name so a future
# reintroduction of a global fallback fails a test with this task's number in
# it, not silently:
#   1. refusal-without-project — no project found -> 127, no global consulted
#   2. vendored routing        — a project IS found -> routes there, unaffected
#   3. subdirectory walk-up    — walking up from inside a project still finds it
#
# A fix that simply always refused (breaking 2 and 3) would pass a test that
# only checked property 1 — hence all three live together in one file.

bats_require_minimum_version 1.5.0

load ../test_helper

ROUTER="$FRAMEWORK_ROOT/bin/fw-router"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export HOME="$TEST_TEMP_DIR/home"
    mkdir -p "$HOME"
    unset FW_ROUTED_FROM FW_ROUTER_TARGET
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

# Same stub shape as fw_router.bats: a fake CLI that reports which copy it is,
# plus the FRAMEWORK.md that makes the vendor copy COMPLETE (T-2811/T-2805 —
# an executable bin/fw with no FRAMEWORK.md reads as an interrupted init and
# the router refuses it rather than routing there).
_stub_cli() {
    mkdir -p "$(dirname "$1")"
    : > "$(dirname "$(dirname "$1")")/FRAMEWORK.md"
    cat > "$1" <<'CLI_EOF'
#!/bin/bash
echo "CLI=$0"
CLI_EOF
    chmod +x "$1"
}

@test "no project anywhere: refuses, no global consulted" {
    local bare="$TEST_TEMP_DIR/bare"
    mkdir -p "$bare"
    cd "$bare"
    run -127 bash "$ROUTER" doctor
    [[ "$output" == *"no framework found"* ]]
    [[ "$output" == *"fw init"* ]]
    # No mention of a global SEARCH — that line was removed with the fallback
    # itself. (The refusal does still reassure "there is no global install to
    # fall back on by design" — that phrase is fine; what must be gone is a
    # "Looked for a global install at ..." line documenting a search that no
    # longer happens.)
    [[ "$output" != *"Looked for a global"* ]]
}

@test "a residue global on the host does not get routed to" {
    # The exact shape that stayed alive pre-T-2854: a directory that LOOKS like
    # a usable global (executable bin/fw) sitting outside any project. Point
    # HOME at it — the only thing that could have consulted it is gone, so
    # routing from an unrelated bare directory must still refuse.
    local fake_global="$HOME/.agentic-framework"
    _stub_cli "$fake_global/bin/fw"
    local bare="$TEST_TEMP_DIR/elsewhere"
    mkdir -p "$bare"
    cd "$bare"
    run -127 bash "$ROUTER" doctor
    [[ "$output" == *"no framework found"* ]]
    [[ "$output" != *"CLI=$fake_global/bin/fw"* ]]
}

@test "vendored consumer project still routes correctly" {
    local proj="$TEST_TEMP_DIR/consumer"
    _stub_cli "$proj/.agentic-framework/bin/fw"
    cd "$proj"
    run bash "$ROUTER" doctor --json
    [ "$status" -eq 0 ]
    [[ "$output" == *"CLI=$proj/.agentic-framework/bin/fw"* ]]
}

@test "walking up from a nested subdirectory still finds the project root" {
    local proj="$TEST_TEMP_DIR/consumer"
    _stub_cli "$proj/.agentic-framework/bin/fw"
    mkdir -p "$proj/src/deep/deeper"
    cd "$proj/src/deep/deeper"
    run bash "$ROUTER" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"CLI=$proj/.agentic-framework/bin/fw"* ]]
}

@test "the framework repo itself still routes to its own bin/fw" {
    local repo="$TEST_TEMP_DIR/framework"
    mkdir -p "$repo"; : > "$repo/FRAMEWORK.md"
    _stub_cli "$repo/bin/fw"
    cd "$repo"
    run bash "$ROUTER" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"CLI=$repo/bin/fw"* ]]
}
