# focus_drift_gate

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/focus_drift_gate.bats`

## What It Does

T-1730: Focus-target drift gate — unit tests
Closes G1 (Bash matcher gap) + G3 (focus-target drift uninspected) from
T-1729 meta-RCA. Tests the Bash branch of agents/context/check-active-task.sh.
Tests are isolated: each one creates a temporary PROJECT_ROOT with a
.context/working/focus.yaml so we can simulate any focus state without
polluting the real project.

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-active-task](/docs/generated/agents-context-check-active-task) | calls | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [init](/docs/generated/lib-init) | calls | fw init - Bootstrap a new project with the Agentic Engineering Framework |
| [check-active-task](/docs/generated/agents-context-check-active-task) | tests | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [init](/docs/generated/lib-init) | tests | fw init - Bootstrap a new project with the Agentic Engineering Framework |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-focus_drift_gate.yaml`*
*Last verified: 2026-05-05*
