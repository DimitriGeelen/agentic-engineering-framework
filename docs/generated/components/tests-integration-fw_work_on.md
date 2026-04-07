# fw_work_on

> Integration tests for fw work-on CLI — 5 tests covering create+focus, resume, nonexistent ID, and help.

**Type:** test | **Subsystem:** framework-core | **Location:** `tests/integration/fw_work_on.bats`

**Tags:** `bats`, `integration-test`, `work-on`, `cli`

## What It Does

Integration tests for fw work-on command
Tests the primary workflow entry point:
fw work-on "name" --type build   — create task + set focus + start
fw work-on T-XXX                 — resume existing task

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | calls |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_work_on.yaml`*
*Last verified: 2026-03-30*
