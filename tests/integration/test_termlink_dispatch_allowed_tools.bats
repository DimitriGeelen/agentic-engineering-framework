#!/usr/bin/env bats
# T-2288: --allowed-tools flag plumb-through for fw termlink dispatch.
#
# Substrate quintet, 5th onion layer. Test surface mirrors T-2284 — we inspect
# the artefacts cmd_dispatch writes (run.sh, allowed_tools.txt, meta.json)
# WITHOUT actually executing the claude -p worker.
#
# Origin: arc010-hma-demo-004 (2026-06-09T13:43Z) — substrate-quartet
# (T-2282/2283/2284/2285) active, worker invoked mcp__fw__work_on twice, got
# "Claude requested permissions to use mcp__fw__work_on, but you haven't
# granted it yet" both times, gave up at turn 8 without closing T-2273.
# --allowed-tools pre-grants per-tool trust so non-interactive workers don't
# stall on the per-tool approval prompt.

load ../test_helper

setup() {
    export TL_TEST_TMPDIR="$(mktemp -d)"
    export TERMLINK_WORKER_TIMEOUT=60
}

teardown() {
    [ -n "${TL_TEST_TMPDIR:-}" ] && rm -rf "$TL_TEST_TMPDIR"
}

@test "t1: flag declared in cmd_dispatch local vars" {
    grep -q 'allowed_tools=""' "$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
}

@test "t2: --allowed-tools case branch consumes the flag value" {
    grep -qE -- '--allowed-tools\)' "$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
    # Window must span the comment block above the assignment line (T-2288 comment
    # is ~13 lines). -A20 is comfortable margin; sibling T-2284 t3 set -A10 with
    # a shorter comment block.
    out=$(grep -F -A20 -- '--allowed-tools)' "$FRAMEWORK_ROOT/agents/termlink/termlink.sh")
    # Assert the assignment (the literal `$2` token, double-quoted in source).
    echo "$out" | grep -qE 'allowed_tools="\$2"'
    # Negative-assert: case branch uses `shift 2` (consumes value), not bare `shift`.
    echo "$out" | grep -q 'shift 2 ;;'
}

@test "t3: allowed_tools.txt write is conditional on flag being non-empty" {
    # Avoid empty-string artefact for default callers (zero blast radius).
    out=$(grep -B0 -A3 'allowed_tools_json="null"' "$FRAMEWORK_ROOT/agents/termlink/termlink.sh")
    echo "$out" | grep -qE 'if \[ -n "\$allowed_tools" \]'
    grep -qE 'allowed_tools\.txt' "$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
}

@test "t4: meta.json schema includes allowed_tools key" {
    grep -qE '"allowed_tools":' "$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
}

@test "t5: run.sh constructs ALLOWED_TOOLS_FLAG from allowed_tools.txt" {
    grep -qE 'ALLOWED_TOOLS_FLAG="--allowed-tools \$\(cat "\$WDIR/allowed_tools.txt"\)"' \
        "$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
    # Composes with file-exists + non-empty check (mirror T-2284 mcp_config pattern).
    out=$(grep -B1 -A2 'ALLOWED_TOOLS_FLAG="--allowed-tools' \
        "$FRAMEWORK_ROOT/agents/termlink/termlink.sh")
    echo "$out" | grep -qE 'if \[ -f "\$WDIR/allowed_tools\.txt" \] && \[ -s "\$WDIR/allowed_tools\.txt" \]'
}

@test "t6: claude -p invocation includes \$ALLOWED_TOOLS_FLAG between \$STRICT_MCP_FLAG and --output-format" {
    grep -qE 'claude -p .*\$STRICT_MCP_FLAG \$ALLOWED_TOOLS_FLAG --output-format' \
        "$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
}

@test "t7: dispatch help mentions --allowed-tools" {
    out=$(bash "$FRAMEWORK_ROOT/bin/fw" termlink help 2>&1)
    echo "$out" | grep -q 'allowed-tools'
    # Help block mentions the example token shape, so authors know what to pass.
    echo "$out" | grep -q 'mcp__fw__'
}

@test "t8: backward-compat — no allowed_tools.txt artefact when flag absent" {
    # The code path: `if [ -n "$allowed_tools" ]; then ... ; fi`. Assert the guard.
    grep -qE 'if \[ -n "\$allowed_tools" \]' "$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
}

@test "t9: substrate quintet ordering — case branch lands after --strict-mcp-config" {
    # Authoring discipline: substrate flags are grouped together. Position assertion
    # protects against a future refactor that splits the cluster.
    out=$(grep -nE -- '--(strict-mcp-config|allowed-tools)\)' "$FRAMEWORK_ROOT/agents/termlink/termlink.sh" | head -2)
    # Two lines, --strict-mcp-config first then --allowed-tools.
    first=$(echo "$out" | sed -n '1p')
    second=$(echo "$out" | sed -n '2p')
    echo "$first" | grep -q 'strict-mcp-config'
    echo "$second" | grep -q 'allowed-tools'
}

@test "t10: live smoke — bin/fw termlink help renders without error and includes example tokens" {
    out=$(bash "$FRAMEWORK_ROOT/bin/fw" termlink help 2>&1)
    [ -n "$out" ]
    # The example string must include both an MCP tool and a built-in tool to
    # signal that the list mixes prefixes — otherwise authors might assume MCP-only.
    echo "$out" | grep -q 'mcp__fw__work_on'
    echo "$out" | grep -qE '(Read|Write|Bash)'
}
