# arc_membership_shared

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/arc_membership_shared.bats`

## What It Does

T-1880 (T-NEW-15): pin shared shell API for arc-membership scans.
Sibling to tests/unit/arc_membership_agent_surfaces.bats (which pins
consumer-site behaviour). This file pins the SHARED LIBRARY itself.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [arc_membership-sh](/docs/generated/lib-arc_membership-sh) | tests | Canonical shell helper for arc-membership scans (T-1880 / T-NEW-15). Consolidates the union-of-`arc_id:`-frontmatter + legacy `arc:<slug>`-tag scan that previously lived inline in three shell consumers: lib/arc.sh, agents/handover/handover.sh, lib/evolution_log.sh. Companion to lib/arc_membership.py (which serves the Python/Flask side).  Public API (PROJECT_ROOT must be set):   arc_tasks_with_arc_id <slug>   → T-IDs whose `arc_id:` matches slug   arc_tasks_with_tag <tag>       → T-IDs whose `tags:` includes tag  Origin: silent-corpus #1 (T-1874/75/76/77) and #2 (T-1879) — captured as L-397. Each inline consumer had to be migrated independently after the T-1850 tags-to-arc_id storage migration; consolidation prevents the next storage-format migration from leaking through nine sites again. |
| [arc_membership-sh](/docs/generated/lib-arc_membership-sh) | calls | Canonical shell helper for arc-membership scans (T-1880 / T-NEW-15). Consolidates the union-of-`arc_id:`-frontmatter + legacy `arc:<slug>`-tag scan that previously lived inline in three shell consumers: lib/arc.sh, agents/handover/handover.sh, lib/evolution_log.sh. Companion to lib/arc_membership.py (which serves the Python/Flask side).  Public API (PROJECT_ROOT must be set):   arc_tasks_with_arc_id <slug>   → T-IDs whose `arc_id:` matches slug   arc_tasks_with_tag <tag>       → T-IDs whose `tags:` includes tag  Origin: silent-corpus #1 (T-1874/75/76/77) and #2 (T-1879) — captured as L-397. Each inline consumer had to be migrated independently after the T-1850 tags-to-arc_id storage migration; consolidation prevents the next storage-format migration from leaking through nine sites again. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-arc_membership_shared.yaml`*
*Last verified: 2026-05-17*
