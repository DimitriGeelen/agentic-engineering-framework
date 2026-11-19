# t5225_termlink_only_hook

> T-5225 — TermLink-only rule: Claude Code's cross-session messaging tools (SendMessage, SendToProject, SendToProjectContext) are refused by the PreToolUse hook agents/context/block-cross-session-messages.sh, every other tool is allowed, an…

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5225_termlink_only_hook.bats`

## What It Does

T-5225 — TermLink-only rule: Claude Code's cross-session messaging tools
(SendMessage, SendToProject, SendToProjectContext) are refused by the
PreToolUse hook agents/context/block-cross-session-messages.sh, every other
tool is allowed, an unreadable payload is refused (fail CLOSED), and the
hook reaches consumers through `fw init` and `fw upgrade`.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5225_termlink_only_hook.yaml`*
*Last verified: 2026-11-18*
