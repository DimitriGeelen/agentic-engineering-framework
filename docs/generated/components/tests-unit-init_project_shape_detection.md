# init_project_shape_detection

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/init_project_shape_detection.bats`

## What It Does

T-2723 (arc-015) — project-shape detection guard for F-10.
Sibling of tests/unit/greenfield_seed_audit_prototype.bats (T-2703), which asks a
DIFFERENT question. That one asks: once a project has been seeded greenfield, is the
greenfield seed set internally consistent enough to pass its own audit? This one asks
the question that precedes it: given a directory with real code in it, does `fw init`
conclude "existing project" at all?
The distinction matters because a misclassified project can pass the T-2703 prototype
perfectly — the greenfield seed set is consistent with itself no matter which directory
it was wrongly applied to. Seed-set health is not shape-detection health.
F-10 (measured under T-2718, 2026-08-02): lib/init.sh consults a seven-entry manifest

---
*Auto-generated from Component Fabric. Card: `tests-unit-init_project_shape_detection.yaml`*
*Last verified: 2026-08-02*
