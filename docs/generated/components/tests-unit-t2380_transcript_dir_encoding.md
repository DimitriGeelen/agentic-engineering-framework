# t2380_transcript_dir_encoding

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2380_transcript_dir_encoding.bats`

## What It Does

T-2380 — the three transcript-dir read-surfaces (fw costs, discard-manifest,
read-transcript.py) must encode the ~/.claude/projects/<dir> name the way
Claude Code does: EVERY non-alnum char → '-'. The old slash-only sanitizer
(tr '/' '-' / .replace('/', '-')) left dots intact and so looked in a
non-existent directory for any worktree path (which contains '.claude').
Drives REAL code: lib/paths.sh helper, the sourced lib/costs.sh resolver, and
the real agents/capture/read-transcript.py CLI (--dry-run). Plus one static
guard asserting no slash-only sanitizer survives in any of the three files.

## Dependencies (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [colors](/docs/generated/lib-colors) | calls | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [costs](/docs/generated/lib-costs) | calls | Token usage tracking from JSONL transcripts — parses Claude Code session data for cost reporting (T-801) |
| [paths](/docs/generated/lib-paths) | tests | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [costs](/docs/generated/lib-costs) | tests | Token usage tracking from JSONL transcripts — parses Claude Code session data for cost reporting (T-801) |
| [JSONL Transcript Reader](/docs/generated/capture-reader) | tests | Extracts human/agent conversation turns from the current Claude Code session's JSONL transcript. Used by the /capture skill to save volatile conversation content to disk before it is lost. |
| [colors](/docs/generated/lib-colors) | tests | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [discard-manifest](/docs/generated/agents-handover-discard-manifest) | tests | TODO: describe what this component does |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2380_transcript_dir_encoding.yaml`*
*Last verified: 2026-06-13*
