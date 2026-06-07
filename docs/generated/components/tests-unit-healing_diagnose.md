# healing_diagnose

> Unit tests for healing diagnose (26 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/healing_diagnose.bats`

**Tags:** `healing`, `diagnose`, `bats`, `unit-test`

## What It Does

Unit tests for agents/healing/lib/diagnose.sh
Tests pure functions: classify_failure, score_pattern
Note: classify_failure uses `declare -A` associative arrays which are
scoped locally when sourced inside bats functions. We use bash -c
subprocesses to ensure proper scoping of the associative array.

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [healing](/docs/generated/agents-healing-healing) | calls | Healing Agent - Antifragile error recovery and pattern learning |
| [diagnose](/docs/generated/agents-healing-lib-diagnose) | calls | Healing Agent - diagnose command |
| [diagnose](/docs/generated/agents-healing-lib-diagnose) | tests | Healing Agent - diagnose command |

---
*Auto-generated from Component Fabric. Card: `tests-unit-healing_diagnose.yaml`*
*Last verified: 2026-04-05*
