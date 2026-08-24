# migrate-horizon-null-completed

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `bin/migrate-horizon-null-completed.sh`

## What It Does

T-2161 (arc-009 horizon-axis-hardening, Slice 2):
Null the stored `horizon:` field on every file under .tasks/completed/.
Rationale (T-2159 inception Q1=(b), shipped under T-2160):
Render-time `past` is now derived from `_location == 'completed'`. The stored
horizon on completed/ files is behaviorally irrelevant — render no longer
reads it. But ~1828 files carry stale `horizon: now/next/later` from before
T-1068 invariants existed. YAML hygiene: stored value should not lie.
Idempotent: re-running emits `0 changes` once the corpus is clean.
Safe: only touches files where `horizon: <something>` exists in YAML
frontmatter and the value is non-null/non-empty.

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [update_task_horizon_null_on_close](/docs/generated/tests-unit-update_task_horizon_null_on_close) | called_by | TODO: describe what this component does |
| [update_task_horizon_null_on_close](/docs/generated/tests-unit-update_task_horizon_null_on_close) | tests_by | TODO: describe what this component does |
| [self_vendor_parity](/docs/generated/tests-unit-self_vendor_parity) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `bin-migrate-horizon-null-completed.yaml`*
*Last verified: 2026-06-01*
