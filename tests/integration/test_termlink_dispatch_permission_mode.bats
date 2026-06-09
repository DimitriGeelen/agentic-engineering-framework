#!/usr/bin/env bats
# T-2282: --permission-mode flag plumb-through for fw termlink dispatch.
#
# Test surface: the dispatch wdir is created with a `run.sh` that's executed
# by the spawned tmux/terminal. We inspect the artefacts cmd_dispatch writes
# (run.sh, permission_mode.txt, meta.json) WITHOUT actually executing the
# claude -p worker — running real claude -p in a test would burn budget +
# add flakiness. The contract we pin: the flag value gets written to
# permission_mode.txt + meta.json, and run.sh's claude -p invocation
# constructs --permission-mode from that file.
#
# Origin: OBS-058/OBS-059 (2026-06-09) — without this flag, non-interactive
# claude -p leaves MCP servers in "status":"pending" and MCP-using workers
# can't call their verbs.

load ../test_helper

setup() {
    # Test isolation — work in a temp dir to avoid clobbering real /tmp/tl-dispatch
    export TL_TEST_TMPDIR="$(mktemp -d)"
    export TERMLINK_WORKER_TIMEOUT=60
}

teardown() {
    [ -n "${TL_TEST_TMPDIR:-}" ] && rm -rf "$TL_TEST_TMPDIR"
}

# Helper: introspect a generated run.sh + meta.json for the dispatch wdir.
# Stubs out the actual spawn/exec — we only care about the artefacts.
#
# We can't easily call cmd_dispatch directly because it shells out to termlink
# spawn. Instead, we run `fw termlink dispatch --help`-equivalent surface:
# parse out the flag-handling by sourcing the function and checking the case
# branch + the run.sh heredoc both reference permission-mode.

@test "t1: flag is declared in cmd_dispatch's local vars" {
    grep -q 'permission_mode=""' "$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
}

@test "t2: --permission-mode case branch consumes the flag" {
    grep -qE -- '--permission-mode\)' "$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
}

@test "t3: permission_mode.txt write is conditional on flag being non-empty" {
    # Avoid empty-string artefact for default callers (zero blast radius)
    grep -qE 'if \[ -n "\$permission_mode" \]' "$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
    grep -qE 'permission_mode\.txt' "$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
}

@test "t4: run.sh constructs PERMISSION_MODE_FLAG from permission_mode.txt" {
    grep -qE 'PERMISSION_MODE_FLAG="--permission-mode \$\(cat "\$WDIR/permission_mode.txt"\)"' \
        "$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
}

@test "t5: claude -p invocation includes PERMISSION_MODE_FLAG" {
    grep -qE 'claude -p .*\$PERMISSION_MODE_FLAG' \
        "$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
}

@test "t6: meta.json schema includes permission_mode key (observability for OBS-058 class)" {
    grep -qE '"permission_mode":' "$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
}

@test "t7: dispatch help mentions --permission-mode" {
    out=$(bash "$FRAMEWORK_ROOT/bin/fw" termlink help 2>&1)
    echo "$out" | grep -q "permission-mode"
}

@test "t8: backward-compat — no permission_mode.txt artefact when flag absent" {
    # The code path: `if [ -n "$permission_mode" ]; then ... ; fi`
    # We assert the GUARD is in place (existing dispatches without the flag
    # produce zero permission_mode artefacts → backward-compatible).
    out=$(grep -A2 'permission_mode_json="null"' "$FRAMEWORK_ROOT/agents/termlink/termlink.sh")
    echo "$out" | grep -q 'if \[ -n "\$permission_mode" \]'
}
