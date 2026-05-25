# suggest

> Healing Agent - suggest command

**Type:** script | **Subsystem:** healing | **Location:** `agents/healing/lib/suggest.sh`

## What It Does

Healing Agent - suggest command
Get suggestions for all tasks with issues

### Framework Reference

When a new arc is created (via `fw arc create` or `fw work-on` of an arc anchor task), the primary agent runs this 5-step workflow **after the arc's anchor-task body is filled** but **before any driver is approved**. The goal is to surface arc-specific drivers that would distinguish the arc from the global D1-D4 directives. Approval stays with the human (M6, D8).

**Steps (D5 — timing matters):**

*(truncated — see CLAUDE.md for full section)*

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [healing](/docs/generated/agents-healing-healing) | called_by | Healing Agent - Antifragile error recovery and pattern learning |
| [healing_suggest](/docs/generated/tests-unit-healing_suggest) | called_by | Unit tests for healing suggest (9 tests) |
| [healing_suggest](/docs/generated/tests-unit-healing_suggest) | tests_by | Unit tests for healing suggest (9 tests) |

## Related

### Tasks
- T-868: Fix ((count++)) set -e crash in healing suggest.sh
- T-870: Sync vendored .agentic-framework/ with T-868/T-869 bugfixes

---
*Auto-generated from Component Fabric. Card: `agents-healing-lib-suggest.yaml`*
*Last verified: 2026-02-20*
