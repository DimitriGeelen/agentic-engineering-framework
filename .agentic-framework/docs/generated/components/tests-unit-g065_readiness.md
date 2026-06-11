# g065_readiness

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/g065_readiness.bats`

## What It Does

T-2299: G-065 closure-readiness gauge — covers READY against live repo,
NOT_READY when each wiring leg is absent, and --strict exit-code semantics.
Sibling to tests/unit/g066_readiness.bats. Same synthetic-repo strategy:
build a tempdir with `.context/` + selectively populated
`agents/context/check-project-boundary.sh` + `bin/fw` so each NOT_READY
case isolates exactly one failing condition. Avoids touching the live repo.

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [g065-readiness](/docs/generated/tools-g065-readiness) | tests | TODO: describe what this component does |
| [check-project-boundary](/docs/generated/agents-context-check-project-boundary) | tests | PreToolUse hook that blocks Write/Edit/Bash operations targeting paths outside PROJECT_ROOT. Prevents cross-project edits. Part of the project boundary enforcement gate (T-559). |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-g065_readiness.yaml`*
*Last verified: 2026-06-09*
