# keylock_subshell_close

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/keylock_subshell_close.bats`

## What It Does

T-1493: keylock_subshell_close_cmd emits FD-close commands so verification
subshells don't leak lock FDs to long-lived daemons (e.g., .NET VBCSCompiler).
Origin: 003-NTB-ATC-Plugin pickup envelope P-015 / T-146

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [keylock](/docs/generated/lib-keylock) | calls | Advisory file locking: task-level lock files in .context/locks/ to prevent concurrent task modifications. |
| [keylock](/docs/generated/lib-keylock) | tests | Advisory file locking: task-level lock files in .context/locks/ to prevent concurrent task modifications. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-keylock_subshell_close.yaml`*
*Last verified: 2026-04-26*
