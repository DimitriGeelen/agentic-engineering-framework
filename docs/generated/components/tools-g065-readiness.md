# g065-readiness

> G-065 closure-readiness gauge — wiring-presence check.

**Type:** script | **Subsystem:** framework-core | **Location:** `tools/g065-readiness.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-project-boundary](/docs/generated/agents-context-check-project-boundary) | calls | PreToolUse hook that blocks Write/Edit/Bash operations targeting paths outside PROJECT_ROOT. Prevents cross-project edits. Part of the project boundary enforcement gate (T-559). |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [g065_readiness](/docs/generated/tests-unit-g065_readiness) | tests_by | T-2299: G-065 closure-readiness gauge — covers READY against live repo, NOT_READY when each wiring leg is absent, and --strict exit-code semantics. |

---
*Auto-generated from Component Fabric. Card: `tools-g065-readiness.yaml`*
*Last verified: 2026-06-09*
