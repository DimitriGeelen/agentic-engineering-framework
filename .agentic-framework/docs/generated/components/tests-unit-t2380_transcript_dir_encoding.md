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

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2380_transcript_dir_encoding.yaml`*
*Last verified: 2026-06-13*
