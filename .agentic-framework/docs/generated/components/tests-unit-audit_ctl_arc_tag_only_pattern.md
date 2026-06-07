# audit_ctl_arc_tag_only_pattern

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/audit_ctl_arc_tag_only_pattern.bats`

## What It Does

T-1881 (T-NEW-16): pin the ctl-arc-tag-only-pattern audit check.
Verifies that:
1. A clean tree (allowlist-only matches) → PASS line emitted
2. A synthetic violation under web/blueprints/ → FAIL line emitted
3. Matches under tests/ and lib/arc.sh / lib/arc_membership.sh / lib/migrations/
are exempt (allowlist works)
Strategy: exercise only the check block — extract the AWK-pattern logic
directly. Running the full audit.sh per-test would be slow + flaky.

## Dependencies (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [arc_membership-sh](/docs/generated/lib-arc_membership-sh) | calls | Canonical shell helper for arc-membership scans (T-1880 / T-NEW-15). Consolidates the union-of-`arc_id:`-frontmatter + legacy `arc:<slug>`-tag scan that previously lived inline in three shell consumers: lib/arc.sh, agents/handover/handover.sh, lib/evolution_log.sh. Companion to lib/arc_membership.py (which serves the Python/Flask side).  Public API (PROJECT_ROOT must be set):   arc_tasks_with_arc_id <slug>   → T-IDs whose `arc_id:` matches slug   arc_tasks_with_tag <tag>       → T-IDs whose `tags:` includes tag  Origin: silent-corpus #1 (T-1874/75/76/77) and #2 (T-1879) — captured as L-397. Each inline consumer had to be migrated independently after the T-1850 tags-to-arc_id storage migration; consolidation prevents the next storage-format migration from leaking through nine sites again. |
| [arc](/docs/generated/lib-arc) | calls | TODO: describe what this component does |
| [arc-id-migration](/docs/generated/lib-migrations-arc-id-migration) | calls | TODO: describe what this component does |
| [arc](/docs/generated/lib-arc) | tests | TODO: describe what this component does |
| [arc_membership-sh](/docs/generated/lib-arc_membership-sh) | tests | Canonical shell helper for arc-membership scans (T-1880 / T-NEW-15). Consolidates the union-of-`arc_id:`-frontmatter + legacy `arc:<slug>`-tag scan that previously lived inline in three shell consumers: lib/arc.sh, agents/handover/handover.sh, lib/evolution_log.sh. Companion to lib/arc_membership.py (which serves the Python/Flask side).  Public API (PROJECT_ROOT must be set):   arc_tasks_with_arc_id <slug>   → T-IDs whose `arc_id:` matches slug   arc_tasks_with_tag <tag>       → T-IDs whose `tags:` includes tag  Origin: silent-corpus #1 (T-1874/75/76/77) and #2 (T-1879) — captured as L-397. Each inline consumer had to be migrated independently after the T-1850 tags-to-arc_id storage migration; consolidation prevents the next storage-format migration from leaking through nine sites again. |
| [arc-id-migration](/docs/generated/lib-migrations-arc-id-migration) | tests | TODO: describe what this component does |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | tests | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-audit_ctl_arc_tag_only_pattern.yaml`*
*Last verified: 2026-05-17*
