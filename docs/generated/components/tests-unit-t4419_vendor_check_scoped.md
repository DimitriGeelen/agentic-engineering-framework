# t4419_vendor_check_scoped

> T-4419: `vendor self --check` in a task's Verification blocked every close while ANY other worker had an uncommitted framework edit — the check only had a whole-tree scope.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4419_vendor_check_scoped.bats`

## What It Does

T-4419: `vendor self --check` in a task's Verification blocked every close while
ANY other worker had an uncommitted framework edit — the check only had a
whole-tree scope. `--check --task T-XXXX` / `--check --paths p…` check only the
vendored copies of the task's own files and report the rest as "in flight".
t1  task's file in sync + unrelated drifted file → scoped 0, whole-tree 1
t2  task's own file drifted → scoped 1
t3  --paths form: unrelated drift → 0, named drifted path → 1
t4  a "T-A, T-B:" batch subject counts as T-B's commit

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4419_vendor_check_scoped.yaml`*
*Last verified: 2026-10-19*
