# block-cross-session-messages

> Block Claude Code's built-in cross-session messaging tools — TermLink only (T-5225)

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/block-cross-session-messages.sh`

## What It Does

Block Claude Code's built-in cross-session messaging tools — TermLink only (T-5225)
Operator ruling 2026-11-17, confirmed 2026-11-18 (option 1): agent-to-agent
messages go over TermLink. Claude Code's own messaging tools deliver to another
session or project outside TermLink's observability, receipts, untrusted-data
framing and idle-aware delivery, so they are refused here.
Refused tools (evidence in T-5225 ## Decisions):
SendMessage           — messages another session / teammate (to:, message:)
SendToProject         — sends this session's work to a Claude Project
SendToProjectContext  — the read step that exists only to feed SendToProject
Every other tool is allowed (exit 0). A payload that cannot be read is

---
*Auto-generated from Component Fabric. Card: `agents-context-block-cross-session-messages.yaml`*
*Last verified: 2026-11-18*
