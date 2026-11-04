# pr-checks

> pr-checks.sh BASE-REF — the R-12 pull-request checks, one script for both places (R-14, T-5009).

**Type:** script | **Subsystem:** framework-core | **Location:** `agents/testhost/pr-checks.sh`

## What It Does

pr-checks.sh BASE-REF — the R-12 pull-request checks, one script for both places (R-14, T-5009).
Called by the `pr-checks` job of .github/workflows/test.yml and by the isolated test host's
guest (agents/testhost/guest-run.sh). Run from the root of the checkout under test.
phase lint:    bats tests/lint/ (structural invariants)
phase changed: the bats/pytest test files added or changed between BASE-REF...HEAD
Every phase prints `== PHASE <name> start ==` and `== PHASE <name> end rc=N seconds=S ==`.
Both phases always run; the exit code is non-zero when any phase failed (the verdict is the
same as the workflow's two steps had: pass only if both pass).

---
*Auto-generated from Component Fabric. Card: `agents-testhost-pr-checks.yaml`*
*Last verified: 2026-11-03*
