#!/usr/bin/env bats
# T-2284: --mcp-config + --strict-mcp-config flag plumb-through for fw termlink dispatch.
#
# Test surface mirrors T-2282 (test_termlink_dispatch_permission_mode.bats) — we
# inspect the artefacts cmd_dispatch writes (run.sh, mcp_config.txt, strict_mcp,
# meta.json) WITHOUT actually executing the claude -p worker, since running
# real claude -p in a test would burn budget + add flakiness. The contract we
# pin: the flag values get written to wdir + meta.json + the run.sh's
# `claude -p` invocation constructs --mcp-config / --strict-mcp-config from
# those files.
#
# Origin: OBS-060/OBS-061 (2026-06-09) — even with --permission-mode acceptEdits
# (T-2282) MCP servers stay "status":"pending" because the parent's
# permissions.allow has no per-server trust entry. Passing --mcp-config makes
# the worker bring up its own MCP set independently.

load ../test_helper

setup() {
    export TL_TEST_TMPDIR="$(mktemp -d)"
    export TERMLINK_WORKER_TIMEOUT=60
}

teardown() {
    [ -n "${TL_TEST_TMPDIR:-}" ] && rm -rf "$TL_TEST_TMPDIR"
}

@test "t1: flags declared in cmd_dispatch local vars" {
    grep -q 'mcp_config=""' "$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
    grep -q 'strict_mcp=""' "$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
}

@test "t2: --mcp-config case branch consumes the flag value" {
    grep -qE -- '--mcp-config\)' "$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
}

@test "t3: --strict-mcp-config case branch is boolean (no shift 2)" {
    # Boolean flag — code path uses `shift` not `shift 2`; assert by checking
    # the case branch's shape (set strict_mcp=1 + shift once).
    # grep BRE: `)` is literal, no escape needed. Use fgrep-shape via -F is
    # cleanest here since pattern has no regex metas after the dash dash.
    out=$(grep -F -A10 -- '--strict-mcp-config)' "$FRAMEWORK_ROOT/agents/termlink/termlink.sh")
    echo "$out" | grep -q 'strict_mcp=1'
    # Negative-assert: no `shift 2` directly after this case (that would
    # eat the next caller arg by mistake).
    echo "$out" | grep -q 'shift ;;'
    ! echo "$out" | grep -q 'shift 2 ;;'
}

@test "t4: mcp_config.txt write is conditional on flag being non-empty" {
    # Avoid empty-string artefact for default callers (zero blast radius).
    out=$(grep -B0 -A3 'mcp_config_json="null"' "$FRAMEWORK_ROOT/agents/termlink/termlink.sh")
    echo "$out" | grep -qE 'if \[ -n "\$mcp_config" \]'
    grep -qE 'mcp_config\.txt' "$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
}

@test "t5: strict_mcp sentinel write is conditional + boolean json" {
    out=$(grep -B0 -A3 'strict_mcp_json="false"' "$FRAMEWORK_ROOT/agents/termlink/termlink.sh")
    echo "$out" | grep -qE 'if \[ -n "\$strict_mcp" \]'
    echo "$out" | grep -qE 'strict_mcp_json="true"'
}

@test "t6: run.sh constructs MCP_CONFIG_FLAG from mcp_config.txt" {
    grep -qE 'MCP_CONFIG_FLAG="--mcp-config \$\(cat "\$WDIR/mcp_config.txt"\)"' \
        "$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
}

@test "t7: run.sh constructs STRICT_MCP_FLAG from strict_mcp sentinel" {
    grep -qE 'STRICT_MCP_FLAG="--strict-mcp-config"' \
        "$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
    # Composes with sentinel file check, not contents.
    out=$(grep -B1 -A2 'STRICT_MCP_FLAG="--strict-mcp-config"' \
        "$FRAMEWORK_ROOT/agents/termlink/termlink.sh")
    echo "$out" | grep -qE 'if \[ -f "\$WDIR/strict_mcp" \]'
}

@test "t8: claude -p invocation includes both flags" {
    grep -qE 'claude -p .*\$MCP_CONFIG_FLAG .*\$STRICT_MCP_FLAG' \
        "$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
}

@test "t9: meta.json schema includes mcp_config + strict_mcp keys (observability for OBS-060/061 class)" {
    grep -qE '"mcp_config":' "$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
    grep -qE '"strict_mcp":' "$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
}

@test "t10: dispatch help mentions both flags" {
    out=$(bash "$FRAMEWORK_ROOT/bin/fw" termlink help 2>&1)
    echo "$out" | grep -q 'mcp-config'
    echo "$out" | grep -q 'strict-mcp-config'
}

@test "t11: backward-compat — no mcp_config.txt or strict_mcp artefacts when flags absent" {
    # The code paths: `if [ -n "$mcp_config" ]; then ... ; fi` and
    # `if [ -n "$strict_mcp" ]; then ... ; fi`. We assert both GUARDS are in
    # place so existing dispatches without the flags produce zero artefacts.
    grep -qE 'if \[ -n "\$mcp_config" \]' "$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
    grep -qE 'if \[ -n "\$strict_mcp" \]' "$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
}
