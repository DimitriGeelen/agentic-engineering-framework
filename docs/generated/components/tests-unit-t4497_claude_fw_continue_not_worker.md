# t4497_claude_fw_continue_not_worker

> T-4497 — claude-fw's -c must continue the agent's conversation, never a worker's.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4497_claude_fw_continue_not_worker.bats`

## What It Does

T-4497 — claude-fw's -c must continue the agent's conversation, never a worker's.
`claude -c` continues the NEWEST conversation in the folder, and every `claude -p`
worker (fw termlink dispatch) writes a newer one. 055 T-586, measured in 1409-sprind
2026-10-20: `claude-fw -c` was refused because the newest conversation was a live
worker's; once a worker ends, -c resumes ITS transcript as if it were the agent. The
T-179 auto-restart in FW_RESTART_MODE=continue relaunched with the same bare -c.
A worker transcript records entrypoint "sdk-cli"; an interactive one "cli". All
transcripts here are fakes under a temp HOME — ~/.claude is never touched.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4497_claude_fw_continue_not_worker.yaml`*
*Last verified: 2026-10-20*
