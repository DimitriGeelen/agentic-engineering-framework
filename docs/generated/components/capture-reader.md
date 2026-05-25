# JSONL Transcript Reader

> Extracts human/agent conversation turns from the current Claude Code session's JSONL transcript. Used by the /capture skill to save volatile conversation content to disk before it is lost.


**Type:** script | **Subsystem:** capture | **Location:** `agents/capture/read-transcript.py`

**Tags:** `capture`, `jsonl`, `conversation`, `session`, `antifragility`

## What It Does

── ANSI stripping ────────────────────────────────────────────────────────────

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [/capture Skill](/docs/generated/capture-skill) | invoked-by | Emergency ejector seat for untracked conversations. When invoked, reads the JSONL transcript, extracts the current topic's conversation, writes a structured research artifact to docs/reports/, and commits it. Closes the governance gap where pure conversation sessions bypass all framework enforcement. |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [/capture Skill](/docs/generated/capture-skill) | called-by | Emergency ejector seat for untracked conversations. When invoked, reads the JSONL transcript, extracts the current topic's conversation, writes a structured research artifact to docs/reports/, and commits it. Closes the governance gap where pure conversation sessions bypass all framework enforcement. |

---
*Auto-generated from Component Fabric. Card: `capture-reader.yaml`*
