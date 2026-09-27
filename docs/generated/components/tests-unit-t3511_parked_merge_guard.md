# t3511_parked_merge_guard

> T-3511 (OBS-547 prevention leg): a merge of a deliberately-parked branch is refused.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3511_parked_merge_guard.bats`

## What It Does

T-3511 (OBS-547 prevention leg): a merge of a deliberately-parked branch is refused.
END-TO-END BY CONSTRUCTION. Every test below runs the REAL installer into a
synthetic consumer repo and then a REAL `git merge`. Asserting the guard script
in isolation would prove the predicate and say nothing about whether git ever
calls it — and "the gate is written" vs "the gate is reachable where it matters"
are independent facts that look identical from inside the repo (L-573, measured
on check-onboarding-gate: 38 green legs, 0 consumers).
The shape matrix is measured, not assumed (git 2.43.0):
clean merge commit  -> pre-merge-commit fires   -> REFUSED   (the incident's shape)
conflicted merge    -> pre-commit fires later   -> REFUSED

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3511_parked_merge_guard.yaml`*
*Last verified: 2026-09-26*
