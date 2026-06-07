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

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [escalation-scan-v0.5](/docs/generated/tools-escalation-scan-v0-5) | calls | TODO: describe what this component does |
| [test_escalation_v05](/docs/generated/tests-playwright-test_escalation_v05) | calls | TODO: describe what this component does |
| [escalation-scan-v0.5](/docs/generated/tools-escalation-scan-v0-5) | tests | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-escalation_scan_v05.yaml`*
*Last verified: 2026-05-05*
