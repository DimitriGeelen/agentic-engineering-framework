# audit_corpus_lint_findings

> T-2985 (arc-014, designer-corpus): corpus-lint findings reach the daily audit.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/audit_corpus_lint_findings.bats`

## What It Does

T-2985 (arc-014, designer-corpus): corpus-lint findings reach the daily audit.
The detectors already worked. What did not exist was a route from "a rule fired"
to "somebody knows". `fw corpus lint` is not in audit, not on cron, not in any
`## Verification` block — so a finding persisted for as long as nobody typed the
command. T-2984's two findings stood ~4 weeks that way, on a map vendored into
every consumer and referenced by an onboarding seed.
The tier is the design decision, so it is the thing most carefully pinned here.
WARN, not FAIL, diverging from the T-2980 seed-reference sibling: corpus findings
are not homogeneous (aef-dispatch-loop's emitterless-typed-event is a real seam,
not a defect), and an audit that exits 2 on a correct corpus trains people to stop

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [corpus_lint](/docs/generated/tools-corpus_lint) | calls | corpus_lint — per-map + cross-map lint for the designer corpus (T-2604). |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | tests | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [corpus_lint](/docs/generated/tools-corpus_lint) | tests | corpus_lint — per-map + cross-map lint for the designer corpus (T-2604). |

---
*Auto-generated from Component Fabric. Card: `tests-unit-audit_corpus_lint_findings.yaml`*
*Last verified: 2026-08-14*
