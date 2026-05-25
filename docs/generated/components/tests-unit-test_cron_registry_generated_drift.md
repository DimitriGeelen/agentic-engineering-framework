# test_cron_registry_generated_drift

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_cron_registry_generated_drift.bats`

## What It Does

T-1942 — Pin fw doctor registry → generated drift detection.
Origin: T-1935/T-1941 — bvp-cost-estimator-sweep entry was added to
cron-registry.yaml but `fw cron generate` was never run; doctor's existing
check covers generated → deployed (both stale, matched), so it reported
"Cron registry in sync" for 3+ days while the new entry was invisible to
the OS scheduler.
This test pins the registry → generated leg: when cron-registry.yaml is
ahead of .context/cron/agentic-audit.crontab, doctor must emit a WARN
pointing at `fw cron generate`. When in sync, the existing OK line stays.

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_cron_registry_generated_drift.yaml`*
*Last verified: 2026-05-19*
