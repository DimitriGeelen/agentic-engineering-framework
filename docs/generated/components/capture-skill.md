# /capture Skill

> Emergency ejector seat for untracked conversations. When invoked, reads the JSONL transcript, extracts the current topic's conversation, writes a structured research artifact to docs/reports/, and commits it. Closes the governance gap where pure conversation sessions bypass all framework enforcement.


**Type:** skill | **Subsystem:** capture | **Location:** `.claude/commands/capture.md`

**Tags:** `capture`, `skill`, `conversation`, `session-capture`, `governance`

## What It Does

/capture - Emergency Conversation Capture

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `agents/capture/read-transcript.py` | calls |
| `agents/context/lib/focus.sh` | reads |

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `agents/capture/read-transcript.py` | used-by |

---
*Auto-generated from Component Fabric. Card: `capture-skill.yaml`*
