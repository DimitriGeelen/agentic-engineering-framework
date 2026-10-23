# t4523_unit_suite_tree_guard

> T-4523: the unit-suite runner must notice when the tests change the checkout they run in. ring20's clean-room run left ~146 tracked files modified or deleted in its clone, and the runner graded only the tests, never the tree.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4523_unit_suite_tree_guard.bats`

## What It Does

T-4523: the unit-suite runner must notice when the tests change the checkout
they run in. ring20's clean-room run left ~146 tracked files modified or
deleted in its clone, and the runner graded only the tests, never the tree.
Also: the runner must not hand the caller's PROJECT_ROOT to the tests (a run
in a clone wrote handovers and arcs into the live repo through it).
HERMETIC BY CONSTRUCTION: the runner is pointed at a fixture corpus inside a
fixture git repo in $BATS_TEST_TMPDIR. The real tests/unit corpus is never run.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4523_unit_suite_tree_guard.yaml`*
*Last verified: 2026-10-21*
