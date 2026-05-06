# escalation_scan_v05

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/escalation_scan_v05.bats`

## What It Does

T-1727 — escalation-scan v0.5 unit coverage.
Pins the structural invariants that A2/A3/A4/A5/A6/A9 depend on. Per AC A8
the rule is "≥1 test per AC" — this file covers the AC subset that is
bats-testable; A5 UI rendering is pinned by tests/playwright/test_escalation_v05.py
and A7 (Evolution log) is part of the task file itself, not source.

## Dependencies (4)

| Target | Relationship |
|--------|-------------|
| `tools/escalation-scan-v0.5.py` | calls |
| `tests/playwright/test_escalation_v05.py` | calls |
| `tools/escalation-scan-v0.5.py` | tests |
| `bin/fw` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-escalation_scan_v05.yaml`*
*Last verified: 2026-05-05*
