# approvals_close_ready_arcs

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/approvals_close_ready_arcs.bats`

## What It Does

T-1961: _load_close_ready_arcs() filter logic.
Pinned via fixture arc YAMLs + fixture anchor task with `## Recommendation`.
Three filter dimensions:
1. status == "in-progress" (closed/abandoned/draft excluded)
2. completion_ratio >= 0.80
3. anchor-task has a non-empty `## Recommendation` block (verdict OK to be '?')

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [approvals](/docs/generated/web-blueprints-approvals) | tests | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-approvals_close_ready_arcs.yaml`*
*Last verified: 2026-07-22*
