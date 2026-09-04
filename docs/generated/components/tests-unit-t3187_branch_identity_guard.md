# t3187_branch_identity_guard

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3187_branch_identity_guard.bats`

## What It Does

T-3187: the branch guard must assert IDENTITY, not reconcilability.
Every pre-existing finding class in lib/branch-hygiene.sh asks "can this
branch still be reconciled?" — none asks "is this the branch we are meant
to be on?". The session sat on t2539-staging for 41 days, 0 BEHIND master
the whole time, so `diverged-fork` never had a reason to fire.
The trap this suite exists to avoid: on a CORRECT branch the guard is
silent, and silence is precisely what the broken guard produced too. So
"silent here" is worthless as evidence on its own. Every quiet assertion
below is paired with a firing one over the same fixture — that pairing is
the control leg.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [branch-hygiene](/docs/generated/lib-branch-hygiene) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3187_branch_identity_guard.yaml`*
*Last verified: 2026-08-26*
