# g065-readiness

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tools/g065-readiness.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-project-boundary](/docs/generated/agents-context-check-project-boundary) | calls | PreToolUse hook that blocks Write/Edit/Bash operations targeting paths outside PROJECT_ROOT. Prevents cross-project edits. Part of the project boundary enforcement gate (T-559). |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [g065_readiness](/docs/generated/tests-unit-g065_readiness) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tools-g065-readiness.yaml`*
*Last verified: 2026-06-09*
