# check_inception_recommendation

> T-2205: PreToolUse Write/Edit hook tests for check-inception-recommendation.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/check_inception_recommendation.bats`

## What It Does

T-2205: PreToolUse Write/Edit hook tests for check-inception-recommendation.
Mirrors tests/unit/check_arc_id.bats / check_inception_decisions.bats shape:
build the stdin JSON envelope Claude Code would send, invoke the hook,
assert exit code + stderr.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-inception-recommendation](/docs/generated/agents-context-check-inception-recommendation) | tests | T-2205: PreToolUse Write/Edit hook — refuse save when inception task has template-only ## Recommendation block under $CLAUDECODE=1. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-check_inception_recommendation.yaml`*
*Last verified: 2026-06-04*
