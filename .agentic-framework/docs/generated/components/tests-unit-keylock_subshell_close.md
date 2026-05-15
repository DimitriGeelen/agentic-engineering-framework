# keylock_subshell_close

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/keylock_subshell_close.bats`

## What It Does

T-1493: keylock_subshell_close_cmd emits FD-close commands so verification
subshells don't leak lock FDs to long-lived daemons (e.g., .NET VBCSCompiler).
Origin: 003-NTB-ATC-Plugin pickup envelope P-015 / T-146

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `lib/keylock.sh` | calls |
| `lib/keylock.sh` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-keylock_subshell_close.yaml`*
*Last verified: 2026-04-26*
