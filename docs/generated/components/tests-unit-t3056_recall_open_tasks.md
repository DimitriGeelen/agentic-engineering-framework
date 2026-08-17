# t3056_recall_open_tasks

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3056_recall_open_tasks.bats`

## What It Does

T-3056 — memory recall must see the OPEN task corpus, not only knowledge
harvested from closed work.
The three failure directions, all of which look like success from outside:
- not firing at all       -> the original bug, unchanged
- firing on itself        -> `fw context focus T-X` recalls T-X (A2)
- firing on everything    -> open tasks take every slot, learnings vanish (A3)
Fixtures use nonsense vocabulary so a hit cannot come from the real corpus.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3056_recall_open_tasks.yaml`*
*Last verified: 2026-08-17*
