# check-visual-verification

> TODO: describe what this component does

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-visual-verification.sh`

## What It Does

Visual Verification Hook — PreToolUse Bash gate
Blocks `git commit` when staged changes include .css/.html files
unless the active task body contains a `## Visual Verification` section
with at least one image-file reference (.png/.jpg/.jpeg).
Rationale: codifies PL-018 / CLAUDE.md "Visual Verification for UI Changes".
DOM measurements ≠ visual proof. Element-level Playwright screenshots in
every visual mode the change spans, READ each screenshot, before claiming fixed.
Canonical failure case: T-489 in 025-WokrshopDesigner (fixed in serif, broke
mono — caught by user on visual inspection because the agent only used DOM rect
math). Adopted as framework artifact from 025-WokrshopDesigner (T-2128).

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-visual-verification.yaml`*
*Last verified: 2026-05-30*
