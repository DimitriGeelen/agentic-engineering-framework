# test_workflow_env_isolation

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_workflow_env_isolation.bats`

## What It Does

T-1700 AC6 — workflow env: plumb-through isolation invariants.
Pins the structural guarantees that prevent workflow-declared env vars
(ANTHROPIC_BASE_URL, ANTHROPIC_API_KEY, etc) from leaking into:
1. The parent shell that ran `fw termlink dispatch`.
2. A second worker spawned without `--env` (must not inherit A's env).
3. The captured envelope (meta.json records keys, NOT values — possible secrets).
Approach: static-analysis checks against the implementation in
agents/termlink/termlink.sh. The structural shape of env handling is what
guarantees isolation — any change that breaks it should break a test here.
A live spawn test is intentionally avoided (slow, requires hub running).

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `agents/termlink/termlink.sh` | calls |
| `agents/termlink/termlink.sh` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_workflow_env_isolation.yaml`*
*Last verified: 2026-05-04*
