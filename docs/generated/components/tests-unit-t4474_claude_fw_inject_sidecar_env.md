# t4474_claude_fw_inject_sidecar_env

> T-4474 — the line claude-fw injects into a TermLink PTY must hand the arc-011 sidecar sockets (TERMLINK_SIDECAR_SOCKET / _STATUS_SOCKET) to the claude it launches.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4474_claude_fw_inject_sidecar_env.bats`

## What It Does

T-4474 — the line claude-fw injects into a TermLink PTY must hand the arc-011
sidecar sockets (TERMLINK_SIDECAR_SOCKET / _STATUS_SOCKET) to the claude it
launches. The PTY shell is spawned by termlink, not by claude-fw, and termlink
>= 0.12.665 no longer forwards them (010-termlink T-3464, pickup offset 342).
The injected line and the prefix helper are taken from bin/claude-fw's own
source, rendered with the sockets set or unset, and run in an `env -i` bash
(no sockets in its environment, as in the PTY) with a stand-in claude binary.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4474_claude_fw_inject_sidecar_env.yaml`*
*Last verified: 2026-10-20*
