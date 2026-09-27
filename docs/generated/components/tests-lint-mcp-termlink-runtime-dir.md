# mcp-termlink-runtime-dir

> T-3424 — the MCP termlink server must be pinned to the canonical hub store.

**Type:** script | **Subsystem:** tests | **Location:** `tests/lint/mcp-termlink-runtime-dir.bats`

## What It Does

T-3424 — the MCP termlink server must be pinned to the canonical hub store.
`termlink mcp serve` defaults TERMLINK_RUNTIME_DIR to /tmp/termlink-0, a
separate store from the systemd hub's /var/lib/termlink. Every MCP channel
tool then reads and writes a store nobody else is on, and channel_post's
offset + channel_state's read-back make posting into the void look like
success (1409-sprind OBS-034; confirmed here 2026-09-22 — the shadow store
already held a sidecar:999-Agentic-Engineering-Framework topic). This pin
keeps .mcp.json's termlink env naming the runtime dir explicitly.

---
*Auto-generated from Component Fabric. Card: `tests-lint-mcp-termlink-runtime-dir.yaml`*
*Last verified: 2026-09-22*
