# ac_structure_close_gate

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/ac_structure_close_gate.bats`

## What It Does

T-3029 -- Regression: update-task.sh's close-time AC gate must not silently
report zero Human ACs when a `### Human` heading is separated from
`## Acceptance Criteria` by an intervening `## ` heading.
Origin: T-3028 was archived to completed/ with owner:agent and an unticked
[REVIEW] Human AC still in the body, because
`sed -n '/^## Acceptance Criteria/,/^## /p'` closed the AC section at
`## Measured Result` -- which sat between `### Agent` and `### Human` --
before the parser ever saw the Human heading. T-2420's PreToolUse hook
prevents this shape from being *written* (once wired into
.claude/settings.json), but does not cover files already malformed on

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [update-task](/docs/generated/agents-task-create-update-task) | calls | Task Update Agent - Status transitions with auto-triggers |
| [update-task](/docs/generated/agents-task-create-update-task) | tests | Task Update Agent - Status transitions with auto-triggers |

---
*Auto-generated from Component Fabric. Card: `tests-unit-ac_structure_close_gate.yaml`*
*Last verified: 2026-08-16*
