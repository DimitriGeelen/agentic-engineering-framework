# t3346_termlink_exit_marker

> T-3346 — claude-fw --termlink must not tear down its own live claude.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3346_termlink_exit_marker.bats`

## What It Does

T-3346 — claude-fw --termlink must not tear down its own live claude.
The old exit-detection grepped PTY output for shell-prompt glyphs, and `❯` —
Claude Code's own TUI input caret — matched while claude was RUNNING. The
wrapper concluded "claude exited", exited itself, and its cleanup trap injected
`exit` into the PTY, killing the session ~1 min after every launch (captured
live 2026-09-07, session claude-master-3884548).
These tests lift _tl_claude_exit_code out of the real wrapper (house style:
claude_fw_restart_mode.bats) so editing bin/claude-fw moves the assertions.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3346_termlink_exit_marker.yaml`*
*Last verified: 2026-09-07*
