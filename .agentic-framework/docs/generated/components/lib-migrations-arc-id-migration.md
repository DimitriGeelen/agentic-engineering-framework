# arc-id-migration

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/migrations/arc-id-migration.sh`

## What It Does

T-1850 (T-NEW-3): one-shot, idempotent migration `tags:[arc:X] → arc_id: X`.
Scans .tasks/{active,completed}/*.md and rewrites frontmatter:
- Removes every `arc:<slug>` entry from the `tags:` list.
- Adds an `arc_id: <slug>` (or `arc_id: arc-NNN` for T-1848 form) field
IMMEDIATELY after the `related_tasks:` line.
- If a task has 0 arc tags → no change.
- If a task has exactly 1 arc tag AND the arc exists → migrate.
- If a task has exactly 1 arc tag but the arc YAML is missing (stale ref)
→ clear the tag, do NOT set arc_id (would fail T-1849 hook); log WARN.
- If a task has >1 arc tags → halt unless --resolve T-XXXX=ARC_ID supplied

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit_ctl_arc_tag_only_pattern](/docs/generated/tests-unit-audit_ctl_arc_tag_only_pattern) | called_by | TODO: describe what this component does |
| [audit_ctl_arc_tag_only_pattern](/docs/generated/tests-unit-audit_ctl_arc_tag_only_pattern) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-migrations-arc-id-migration.yaml`*
*Last verified: 2026-05-16*
