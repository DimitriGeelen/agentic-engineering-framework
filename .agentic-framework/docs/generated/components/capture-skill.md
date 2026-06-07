# /capture Skill

> Emergency ejector seat for untracked conversations. When invoked, reads the JSONL transcript, extracts the current topic's conversation, writes a structured research artifact to docs/reports/, and commits it. Closes the governance gap where pure conversation sessions bypass all framework enforcement.


**Type:** skill | **Subsystem:** capture | **Location:** `.claude/commands/capture.md`

**Tags:** `capture`, `skill`, `conversation`, `session-capture`, `governance`

## What It Does

/capture - Emergency Conversation Capture

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [JSONL Transcript Reader](/docs/generated/capture-reader) | calls | Extracts human/agent conversation turns from the current Claude Code session's JSONL transcript. Used by the /capture skill to save volatile conversation content to disk before it is lost. |
| [focus](/docs/generated/agents-context-lib-focus) | reads | Context Agent - focus command |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [JSONL Transcript Reader](/docs/generated/capture-reader) | used-by | Extracts human/agent conversation turns from the current Claude Code session's JSONL transcript. Used by the /capture skill to save volatile conversation content to disk before it is lost. |

---
*Auto-generated from Component Fabric. Card: `capture-skill.yaml`*
