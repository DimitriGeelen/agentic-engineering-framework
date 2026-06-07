# audit_stale_slice_reference

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/audit_stale_slice_reference.bats`

## What It Does

T-1975 (L-417 prevention): pin the stale-slice-reference audit check.
Verifies:
1. Clean tree → PASS line emitted
2. Seeded "ship in T-NNNN" where T-NNNN is in .tasks/completed/ → WARN
3. Seeded "ship in T-NNNN" where T-NNNN is ACTIVE → does NOT WARN
4. Allowlisted paths (tests/, docs/, audit.sh self) → exempt
5. "once that slice ships" phrasing → WARN regardless of T-NNNN
Strategy: isolated synthetic PROJECT_ROOT + check-block logic extracted
inline (same pattern as audit_ctl_arc_tag_only_pattern.bats).

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [arcs](/docs/generated/web-blueprints-arcs) | calls | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [arcs](/docs/generated/web-blueprints-arcs) | tests | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-audit_stale_slice_reference.yaml`*
*Last verified: 2026-05-21*
