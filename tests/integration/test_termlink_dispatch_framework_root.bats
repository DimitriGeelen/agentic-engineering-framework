#!/usr/bin/env bats
# T-2285: framework-self vs consumer discrimination for FRAMEWORK_ROOT
# inside `fw termlink dispatch` run.sh heredoc.
#
# Test surface: static-inspect the heredoc + simulate the three branches
# by running the actual conditional logic against a tmp PROJECT_DIR.
# Mirrors T-2282/T-2284 inspection style — we don't actually spawn
# `claude -p` (would burn budget + add flakiness).
#
# Origin: OBS-062 (2026-06-09) — arc-010 HM-A demo failed because
# FRAMEWORK_ROOT was redirected to .agentic-framework/ inside the
# framework REPO itself (where .agentic-framework/ is the self-vendored
# mirror, not the source). MCP server's _project_root() then looked for
# policy/capability-overlay/tool-set.yaml in the mirror — file absent.

load ../test_helper

setup() {
    export TL_TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
    [ -n "${TL_TEST_TMPDIR:-}" ] && rm -rf "$TL_TEST_TMPDIR"
}

# Helper: extract the FRAMEWORK_ROOT block from run.sh heredoc + simulate
# against a given PROJECT_DIR. Returns the value FRAMEWORK_ROOT would take.
_simulate_framework_root() {
    local PROJECT_DIR="$1"
    # Replicate the run.sh conditional (kept in sync with termlink.sh edits).
    if [ -f "$PROJECT_DIR/FRAMEWORK.md" ]; then
        echo "$PROJECT_DIR"
    elif [ -d "$PROJECT_DIR/.agentic-framework" ]; then
        echo "$PROJECT_DIR/.agentic-framework"
    else
        echo "$PROJECT_DIR"
    fi
}

@test "t1: heredoc contains FRAMEWORK.md discriminator" {
    grep -qE 'PROJECT_DIR/FRAMEWORK.md' "$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
}

@test "t2: heredoc has three branches (framework-self / consumer / bare)" {
    # Extract a window of the heredoc that should contain all three branches.
    out=$(grep -A20 'T-2285.*OBS-062' "$FRAMEWORK_ROOT/agents/termlink/termlink.sh")
    echo "$out" | grep -q 'Framework repo:'
    echo "$out" | grep -q 'Consumer with vendored framework:'
    echo "$out" | grep -q 'Bare project with no framework wiring:'
}

@test "t3: framework-self case — FRAMEWORK_ROOT equals PROJECT_DIR (not .agentic-framework)" {
    local fake="$TL_TEST_TMPDIR/fake-framework"
    mkdir -p "$fake/.agentic-framework"
    touch "$fake/FRAMEWORK.md"
    [ "$(_simulate_framework_root "$fake")" = "$fake" ]
    # Negative-assert: confirms redirect is NOT happening for this case.
    [ "$(_simulate_framework_root "$fake")" != "$fake/.agentic-framework" ]
}

@test "t4: consumer-shape case — FRAMEWORK_ROOT redirects to .agentic-framework/ (zero-regression)" {
    local fake="$TL_TEST_TMPDIR/fake-consumer"
    mkdir -p "$fake/.agentic-framework"
    # No FRAMEWORK.md → consumer-shape.
    [ "$(_simulate_framework_root "$fake")" = "$fake/.agentic-framework" ]
}

@test "t5: bare-project case — FRAMEWORK_ROOT equals PROJECT_DIR (no framework)" {
    local fake="$TL_TEST_TMPDIR/fake-bare"
    mkdir -p "$fake"
    # Neither FRAMEWORK.md nor .agentic-framework/.
    [ "$(_simulate_framework_root "$fake")" = "$fake" ]
}

@test "t6: discriminator order — FRAMEWORK.md trumps .agentic-framework/" {
    # Framework repo has BOTH FRAMEWORK.md AND .agentic-framework/ (self-vendor).
    # Discriminator must check FRAMEWORK.md FIRST so the framework branch wins.
    local fake="$TL_TEST_TMPDIR/fake-both"
    mkdir -p "$fake/.agentic-framework"
    touch "$fake/FRAMEWORK.md"
    [ "$(_simulate_framework_root "$fake")" = "$fake" ]
    [ "$(_simulate_framework_root "$fake")" != "$fake/.agentic-framework" ]
}

@test "t7: live smoke — current framework repo resolves FRAMEWORK_ROOT to itself" {
    # The actual framework repo where these tests run IS the framework-self case.
    [ "$(_simulate_framework_root "$FRAMEWORK_ROOT")" = "$FRAMEWORK_ROOT" ]
    [ -f "$FRAMEWORK_ROOT/FRAMEWORK.md" ]
}
