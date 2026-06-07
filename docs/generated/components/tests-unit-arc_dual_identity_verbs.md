# arc_dual_identity_verbs

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/arc_dual_identity_verbs.bats`

## What It Does

T-1848 sequel — verb-side normalisation coverage.
Verifies that arc verbs (focus, show, tag, close) accept BOTH the slug form
(`dispatch-safety`) and the canonical arc-NNN form (`arc-001`) introduced by
T-1848's D-Immutability axiom. Substrate shipped 2026-05-16 (commit cee2a90d)
but verb-side normalisation was deferred to a sequel — this is that sequel.
Pattern: scaffold a throwaway ARCS_DIR under BATS_TEST_TMPDIR, source the
library, run each verb with both forms, assert success + correct routing.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [arc](/docs/generated/lib-arc) | calls | TODO: describe what this component does |
| [arc](/docs/generated/lib-arc) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-arc_dual_identity_verbs.yaml`*
*Last verified: 2026-05-16*
