# audit_ctl013_skip_nested_audit

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/audit_ctl013_skip_nested_audit.bats`

## What It Does

T-1870 / L-391: CTL-013 must skip verification lines that invoke
`bin/fw audit` (or `fw audit`) — running them inside the audit lock
always fails (lock held by the outer audit) and produces false-positive
WARN. The skip-and-continue path treats those lines as if they passed
(with a transparency note in the PASS line: "(N skipped — nested-audit
invocation)").

## Dependencies (3)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | tests |
| `C-004` | calls |
| `C-004` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-audit_ctl013_skip_nested_audit.yaml`*
*Last verified: 2026-05-15*
