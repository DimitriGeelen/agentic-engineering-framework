# discard-manifest

> TODO: describe what this component does

**Type:** script | **Subsystem:** handover | **Location:** `agents/handover/discard-manifest.sh`

## What It Does

discard-manifest.sh — Category-level compaction discard manifest (T-2366, arc-012 S4)
Slice S4 of T-2158 (continuous-run). When the agent self-compacts at a
context-budget boundary, the handover that fires (pre-compact.sh / checkpoint.sh
→ handover.sh, unified under D-028) leaves behind a machine-readable record of
WHAT was discarded, so the operator can review post-hoc.
Category-level fidelity is sufficient and is all that is achievable: the model
self-compacts internally, so a token-level before/after diff is impossible
(T-2158 S6 Q4). This script reports counts and the working-set file list mined
from the current session transcript — the categories that compaction sheds.
Usage:

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [handover](/docs/generated/agents-handover-handover) | called_by | Handover Agent - Mechanical Operations |
| [t2380_transcript_dir_encoding](/docs/generated/tests-unit-t2380_transcript_dir_encoding) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `agents-handover-discard-manifest.yaml`*
*Last verified: 2026-06-13*
