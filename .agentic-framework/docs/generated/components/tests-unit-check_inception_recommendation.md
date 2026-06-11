# check_inception_recommendation

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/check_inception_recommendation.bats`

## What It Does

T-2205: PreToolUse Write/Edit hook tests for check-inception-recommendation.
Mirrors tests/unit/check_arc_id.bats / check_inception_decisions.bats shape:
build the stdin JSON envelope Claude Code would send, invoke the hook,
assert exit code + stderr.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-inception-recommendation](/docs/generated/agents-context-check-inception-recommendation) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-check_inception_recommendation.yaml`*
*Last verified: 2026-06-04*
