# dup-task-scan

> T-1863: Duplicate task-ID scanner (G-052 prevention).

**Type:** script | **Subsystem:** git-traceability | **Location:** `agents/git/lib/dup-task-scan.sh`

## What It Does

T-1863: Duplicate task-ID scanner (G-052 prevention).
Scans the staged tree (or the working tree, depending on mode) for any
T-NNNN identifier that appears in BOTH .tasks/active/ AND .tasks/completed/.
This is the same check `fw audit` runs (T-1279), but at the commit boundary
so orphans cannot survive into a commit.
Mode:
scan-staged    — uses `git ls-files --cached` (default; for pre-commit)
scan-worktree  — uses the on-disk filenames (for ad-hoc checks)
Exit:
0  no duplicates

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hooks](/docs/generated/agents-git-lib-hooks) | called_by | Git Agent - Hook installation subcommand |
| [update_task_orphan_guard](/docs/generated/tests-unit-update_task_orphan_guard) | called_by | T-1863 — Structural prevention for the active+completed orphan class. Origin: T-1859 was marked work-completed in S-2026-0515-2042 but the active/T-1859 file was never removed from the index, leaving both sides tracked. |
| [update_task_orphan_guard](/docs/generated/tests-unit-update_task_orphan_guard) | tests_by | T-1863 — Structural prevention for the active+completed orphan class. Origin: T-1859 was marked work-completed in S-2026-0515-2042 but the active/T-1859 file was never removed from the index, leaving both sides tracked. |

---
*Auto-generated from Component Fabric. Card: `agents-git-lib-dup-task-scan.yaml`*
*Last verified: 2026-05-15*
