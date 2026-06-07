# healing_suggest

> Unit tests for healing suggest (9 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/healing_suggest.bats`

**Tags:** `healing`, `suggest`, `bats`, `unit-test`

## What It Does

Unit tests for agents/healing/lib/suggest.sh
Tests: do_suggest (scan for tasks with issues/blocked status)

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [healing](/docs/generated/agents-healing-healing) | calls | Healing Agent - Antifragile error recovery and pattern learning |
| [yaml](/docs/generated/lib-yaml) | calls | YAML manipulation helpers: Python-based read/write for YAML frontmatter in task files. Used by update-task.sh. |
| [suggest](/docs/generated/agents-healing-lib-suggest) | calls | Healing Agent - suggest command |
| [suggest](/docs/generated/agents-healing-lib-suggest) | tests | Healing Agent - suggest command |
| [yaml](/docs/generated/lib-yaml) | tests | YAML manipulation helpers: Python-based read/write for YAML frontmatter in task files. Used by update-task.sh. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-healing_suggest.yaml`*
*Last verified: 2026-04-05*
