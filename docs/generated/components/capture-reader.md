# JSONL Transcript Reader

> Extracts human/agent conversation turns from the current Claude Code session's JSONL transcript. Used by the /capture skill to save volatile conversation content to disk before it is lost.


**Type:** script | **Subsystem:** capture | **Location:** `agents/capture/read-transcript.py`

**Tags:** `capture`, `jsonl`, `conversation`, `session`, `antifragility`

## What It Does

── ANSI stripping ────────────────────────────────────────────────────────────

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [/capture Skill](/docs/generated/capture-skill) | invoked-by | Emergency ejector seat for untracked conversations. When invoked, reads the JSONL transcript, extracts the current topic's conversation, writes a structured research artifact to docs/reports/, and commits it. Closes the governance gap where pure conversation sessions bypass all framework enforcement. |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [/capture Skill](/docs/generated/capture-skill) | called-by | Emergency ejector seat for untracked conversations. When invoked, reads the JSONL transcript, extracts the current topic's conversation, writes a structured research artifact to docs/reports/, and commits it. Closes the governance gap where pure conversation sessions bypass all framework enforcement. |
| [t2380_transcript_dir_encoding](/docs/generated/tests-unit-t2380_transcript_dir_encoding) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `capture-reader.yaml`*
