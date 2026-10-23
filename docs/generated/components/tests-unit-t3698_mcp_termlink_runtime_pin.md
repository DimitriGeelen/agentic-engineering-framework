# t3698_mcp_termlink_runtime_pin

> T-3698: fw init / fw upgrade wrote a consumer .mcp.json whose termlink server had no env.TERMLINK_RUNTIME_DIR.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3698_mcp_termlink_runtime_pin.bats`

## What It Does

T-3698: fw init / fw upgrade wrote a consumer .mcp.json whose termlink server
had no env.TERMLINK_RUNTIME_DIR. Claude launched without the variable (T-3779)
then ran `termlink mcp serve` on /tmp/termlink-$UID: channel posts landed in a
store no hub reads and read back as delivered. Both producers now pin the live
hub dir, add-only. Fake hubs: a real AF_UNIX socket plus a pidfile naming a
live ($$) pid, as in t3779_termlink_runtime.bats.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3698_mcp_termlink_runtime_pin.yaml`*
*Last verified: 2026-10-20*
