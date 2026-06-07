# test_boundary_hook_arguments

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_boundary_hook_arguments.bats`

## What It Does

T-1702 / G-065 — Pattern 4 (read-side outside-path arguments).
Origin: 2026-05-03 housekeeping. The cd-pattern blocked
`cd /root/.agentic-framework`; the agent then ran `du`/`find`/`grep`
against the same absolute path and the hook stayed silent. Read-side
cross-boundary access had been undetected for as long as the hook
existed (T-559).
These tests pin Pattern 4 behaviour: outside-path arguments to ANY
command are blocked unless the path falls under the read-side
allowlist (system paths, /tmp, project root).

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-project-boundary](/docs/generated/agents-context-check-project-boundary) | calls | PreToolUse hook that blocks Write/Edit/Bash operations targeting paths outside PROJECT_ROOT. Prevents cross-project edits. Part of the project boundary enforcement gate (T-559). |
| [check-project-boundary](/docs/generated/agents-context-check-project-boundary) | tests | PreToolUse hook that blocks Write/Edit/Bash operations targeting paths outside PROJECT_ROOT. Prevents cross-project edits. Part of the project boundary enforcement gate (T-559). |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_boundary_hook_arguments.yaml`*
*Last verified: 2026-05-03*
