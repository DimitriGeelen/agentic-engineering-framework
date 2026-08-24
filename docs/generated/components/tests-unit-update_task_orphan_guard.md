# update_task_orphan_guard

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/update_task_orphan_guard.bats`

## What It Does

T-1863 — Structural prevention for the active+completed orphan class.
Origin: T-1859 was marked work-completed in S-2026-0515-2042 but the
active/T-1859 file was never removed from the index, leaving both sides
tracked. fw audit caught it at next pre-push (G-052 FAIL) — 3 days late.
Two surfaces are exercised here:
1. dup-task-scan.sh — pre-commit gate that refuses staged duplicates.
2. update-task.sh post-move check — refuses to continue if the source
path still exists after the rename (the orphan-creation moment).

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [dup-task-scan](/docs/generated/agents-git-lib-dup-task-scan) | calls | TODO: describe what this component does |
| [dup-task-scan](/docs/generated/agents-git-lib-dup-task-scan) | tests | TODO: describe what this component does |
| [update-task](/docs/generated/agents-task-create-update-task) | calls | Task Update Agent - Status transitions with auto-triggers |
| [update-task](/docs/generated/agents-task-create-update-task) | tests | Task Update Agent - Status transitions with auto-triggers |

---
*Auto-generated from Component Fabric. Card: `tests-unit-update_task_orphan_guard.yaml`*
*Last verified: 2026-05-15*
