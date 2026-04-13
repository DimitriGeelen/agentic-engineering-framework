# no-bare-fw-in-gate-scripts

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/lint/no-bare-fw-in-gate-scripts.bats`

## What It Does

Invariant: gate scripts must not emit bare 'fw' commands — use _emit_user_command/_fw_cmd
Origin: T-1146 GO / T-1203 — bare commands are not copy-pasteable and violate PL-007

---
*Auto-generated from Component Fabric. Card: `tests-lint-no-bare-fw-in-gate-scripts.yaml`*
*Last verified: 2026-04-13*
