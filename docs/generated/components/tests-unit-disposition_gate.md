# disposition_gate

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/disposition_gate.bats`

## What It Does

Unit tests for check_disposition_gate (T-2190).
Inception tasks with ## Open Questions must dispose every IW-N before
work-completed. Each question requires both a `disposition:` and
`rationale:` line. Bypass: --skip-disposition-gate / FW_SKIP_DISPOSITION_GATE=1.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [update-task](/docs/generated/agents-task-create-update-task) | calls | Task Update Agent - Status transitions with auto-triggers |
| [update-task](/docs/generated/agents-task-create-update-task) | tests | Task Update Agent - Status transitions with auto-triggers |

---
*Auto-generated from Component Fabric. Card: `tests-unit-disposition_gate.yaml`*
*Last verified: 2026-06-02*
