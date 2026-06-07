# arc_abandon

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/arc_abandon.bats`

## What It Does

T-1854 (T-NEW-6): fw arc abandon CLI verb.
Allowed source states: draft, in-progress (refused from closed, abandoned).
Refuses without --reason or with --reason text under 30 chars.
Refuses under $CLAUDECODE=1 unless --i-am-human or --from-watchtower.
Appends JSON row to .context/audits/arc-abandon.jsonl.
Mutates arc YAML: status: abandoned, abandoned_at: <iso>, abandonment_reason: <text>.
D-Immutability: arc YAML stays in .context/arcs/ (no move, no delete).

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [arc](/docs/generated/lib-arc) | calls | TODO: describe what this component does |
| [arc](/docs/generated/lib-arc) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-arc_abandon.yaml`*
*Last verified: 2026-05-16*
