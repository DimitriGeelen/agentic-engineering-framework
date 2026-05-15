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

| Target | Relationship |
|--------|-------------|
| `agents/context/check-project-boundary.sh` | calls |
| `agents/context/check-project-boundary.sh` | tests |
| `bin/fw` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_boundary_hook_arguments.yaml`*
*Last verified: 2026-05-03*
