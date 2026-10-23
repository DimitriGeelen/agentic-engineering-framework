# t4048_claude_fw_background_resume

> T-4048 (055 T-491 proposal B) — claude-fw must not --resume a conversation that is a live Claude Code background job.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4048_claude_fw_background_resume.bats`

## What It Does

T-4048 (055 T-491 proposal B) — claude-fw must not --resume a conversation that is
a live Claude Code background job.
Claude Code keeps background jobs (`claude --bg`, and a bare `claude` the agents
view parks in the shared daemon) under ~/.claude/jobs/<first 8 of the session
id>/state.json. `--resume <id>` of a live one becomes a `claude attach` viewer, not
a conversation on the wrapper's tty, so claude-fw's typing path (T-4003) cannot
reach it and the operator gains one more hidden conversation (055: 7 in one day).
The wrapper refuses with exit 3 and names the way to foreground it.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4048_claude_fw_background_resume.yaml`*
*Last verified: 2026-10-21*
