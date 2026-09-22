#!/usr/bin/env bats
# T-3424 — the MCP termlink server must be pinned to the canonical hub store.
#
# `termlink mcp serve` defaults TERMLINK_RUNTIME_DIR to /tmp/termlink-0, a
# separate store from the systemd hub's /var/lib/termlink. Every MCP channel
# tool then reads and writes a store nobody else is on, and channel_post's
# offset + channel_state's read-back make posting into the void look like
# success (1409-sprind OBS-034; confirmed here 2026-09-22 — the shadow store
# already held a sidecar:999-Agentic-Engineering-Framework topic). This pin
# keeps .mcp.json's termlink env naming the runtime dir explicitly.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

@test "mcp-termlink-runtime-dir: .mcp.json termlink server env names TERMLINK_RUNTIME_DIR" {
    run python3 -c "
import json, sys
cfg = json.load(open('$FRAMEWORK_ROOT/.mcp.json'))
srv = cfg['mcpServers']['termlink']
env = srv.get('env') or {}
val = env.get('TERMLINK_RUNTIME_DIR', '')
print(val)
sys.exit(0 if val.startswith('/') else 1)
"
    [ "$status" -eq 0 ]
    [ "$output" = "/var/lib/termlink" ]
}

@test "mcp-termlink-runtime-dir: when the systemd hub is running here, its runtime dir matches the pinned one" {
    # Skip only when there is no hub process to compare against (CI, a
    # consumer host without the systemd unit) — the first test still pins
    # the config on its own.
    pid=$(pgrep -f "termlink hub start" | head -1)
    [ -n "$pid" ] || skip "no termlink hub process on this host"
    hub_dir=$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | sed -n 's/^TERMLINK_RUNTIME_DIR=//p' | head -1)
    [ -n "$hub_dir" ] || skip "hub process environment unreadable"
    cfg_dir=$(python3 -c "import json; print((json.load(open('$FRAMEWORK_ROOT/.mcp.json'))['mcpServers']['termlink'].get('env') or {}).get('TERMLINK_RUNTIME_DIR',''))")
    [ "$cfg_dir" = "$hub_dir" ]
}
