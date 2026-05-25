# inception_recommendation

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/inception_recommendation.sh`

## What It Does

lib/inception_recommendation.sh
Detection helper for the T-679 rule decay pattern (T-1715 meta-RCA,
T-1716 implementation). Used by:
- agents/audit/audit.sh    — C-006 detective check
- lib/inception.sh         — Stream C sweep (do_inception_sweep --recommendation-fix)
Public functions:
has_real_recommendation <task_file>
Returns 0 if file's `## Recommendation` body contains a real
`**Recommendation:** GO|NO-GO|DEFER` line; 1 otherwise.
find_inceptions_without_recommendation <active_dir>

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [inception](/docs/generated/lib-inception) | called_by | fw inception - Inception phase workflow |

---
*Auto-generated from Component Fabric. Card: `lib-inception_recommendation.yaml`*
*Last verified: 2026-05-04*
