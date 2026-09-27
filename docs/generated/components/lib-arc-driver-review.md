# arc-driver-review

> lib/arc-driver-review.sh — T-3429 (arc-006), D-586.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/arc-driver-review.sh`

## What It Does

lib/arc-driver-review.sh — T-3429 (arc-006), D-586.
The external value-driver reviewer. Operator ruling 2026-09-22: arc-scoped
value drivers are created and added by DEFAULT; the §ACD operator-approval
step (T-1926, M6/D8) stops being the default path and becomes the override.
Quality is held here instead — by a check that can be re-run, diffed and
audited, rather than by a click nobody can reproduce six weeks later.
DELIBERATELY NOT MODEL-BACKED. The verdict has to be identical on every run
of the same YAML, or the audit rail below it (check_arc_driver_reviewer_record)
is auditing noise. Three static checks:
(a) SCORABLE  — the estimator can actually score this driver: a hand-written

---
*Auto-generated from Component Fabric. Card: `lib-arc-driver-review.yaml`*
*Last verified: 2026-09-22*
