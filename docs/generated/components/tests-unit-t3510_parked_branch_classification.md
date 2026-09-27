# t3510_parked_branch_classification

> T-3510 (OBS-547): a branch is unlanded for two very different reasons, and the scan could not tell them apart.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3510_parked_branch_classification.bats`

## What It Does

T-3510 (OBS-547): a branch is unlanded for two very different reasons, and the
scan could not tell them apart.
Parking lives in the TASK — `status: captured`, `horizon: later` — and nowhere
in the branch. On 2026-09-26 this scan reported a parked branch as landable,
the audit's mitigation line recommended `fw integrate run`, and a batch-merge
worker did exactly that, taking the `fw arc close` sovereignty gate off by
default. No rule was broken: the rail could not express the distinction.
The trap this suite is built against: a "parked" check that suppresses findings
rather than substituting them would make the scan quieter and look like a pass.
So every firing assertion below is paired with a CONTROL over the same fixture

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3510_parked_branch_classification.yaml`*
*Last verified: 2026-09-26*
