# t4462_claude_fw_inject_bypasses_function

> T-4462 — the line claude-fw injects into a TermLink PTY must reach the claude BINARY, not a user's claude() function or `claude` alias.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4462_claude_fw_inject_bypasses_function.bats`

## What It Does

T-4462 — the line claude-fw injects into a TermLink PTY must reach the claude
BINARY, not a user's claude() function or `claude` alias.
The PTY runs an interactive bash that sources the user's rc, so a bare `claude`
resolves alias → function → PATH. 055-agentic-fleet-cockpit (T-580) had a
claude() front door that caught every fleet start (rc=1). The test builds the
exact injected line from bin/claude-fw's own `termlink_inject "…"` call and runs
it in `bash -i` whose rc defines both, with a stand-in binary on PATH.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4462_claude_fw_inject_bypasses_function.yaml`*
*Last verified: 2026-10-20*
