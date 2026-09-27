# t3358_claude_fw_exit_detection

> T-3358 — claude-fw --termlink exit-detection must fire under a ROOT prompt, not only a `user@` one, and must trigger termlink_cleanup so no session is

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3358_claude_fw_exit_detection.bats`

## What It Does

T-3358 — claude-fw --termlink exit-detection must fire under a ROOT prompt,
not only a `user@` one, and must trigger termlink_cleanup so no session is
orphaned.
RCA (T-3358): the wrapper at some point in its history matched the PTY tail
against an enumerated prompt-glyph alternation (`^user@`, no `root@` branch).
On root-fleet hosts, where every session runs as uid 0, the detector's true
branch was unreachable — exit was never observed, `termlink_cleanup` never
ran, and the TermLink session sat attached to a dead root shell indefinitely.
T-3346 already replaced prompt-glyph matching with an explicit exit marker
(_tl_claude_exit_code) — a fix that is prompt-agnostic by construction and so

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3358_claude_fw_exit_detection.yaml`*
*Last verified: 2026-09-16*
