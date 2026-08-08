# audit_root_commit_traceability

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/audit_root_commit_traceability.bats`

## What It Does

T-2851 — the audit's commit-traceability check must exempt ROOT commits.
`fw init` closes with a bootstrap commit subject `T-000: fw init bootstrap …`
so the new project has a resolvable HEAD (lib/init.sh:742). `T-000` satisfies
the commit-msg hook, which only requires the subject to MATCH `T-[0-9]+`, but
it never resolves to a task file — so the audit's existence check fired on it
and every fresh project failed its own traceability audit on day zero.
Both directions are asserted here. The exemption test alone would be satisfied
by a "fix" that disabled the check outright, which is the failure mode this
whole family keeps producing (T-2843/T-2844/T-2845: green about the wrong
object). The negative control is the load-bearing half.

---
*Auto-generated from Component Fabric. Card: `tests-unit-audit_root_commit_traceability.yaml`*
*Last verified: 2026-08-07*
