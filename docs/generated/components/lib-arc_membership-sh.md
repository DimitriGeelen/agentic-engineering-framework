# arc_membership-sh

> Canonical shell helper for arc-membership scans (T-1880 / T-NEW-15).
Consolidates the union-of-`arc_id:`-frontmatter + legacy `arc:<slug>`-tag
scan that previously lived inline in three shell consumers:
lib/arc.sh, agents/handover/handover.sh, lib/evolution_log.sh.
Companion to lib/arc_membership.py (which serves the Python/Flask side).

Public API (PROJECT_ROOT must be set):
  arc_tasks_with_arc_id <slug>   → T-IDs whose `arc_id:` matches slug
  arc_tasks_with_tag <tag>       → T-IDs whose `tags:` includes tag

Origin: silent-corpus #1 (T-1874/75/76/77) and #2 (T-1879) — captured as
L-397. Each inline consumer had to be migrated independently after the
T-1850 tags-to-arc_id storage migration; consolidation prevents the next
storage-format migration from leaking through nine sites again.


**Type:** library | **Subsystem:** framework-core | **Location:** `lib/arc_membership.sh`

**Tags:** `arc-grooming`, `silent-corpus-prevention`

## What It Does

Canonical shell helper for arc-membership scans.
T-1880 (T-NEW-15, arc-grooming): consolidates the union-of-`arc_id:`-
frontmatter plus legacy `arc:<slug>`-tag scan that previously lived
inline in three places (lib/arc.sh, agents/handover/handover.sh,
lib/evolution_log.sh).
Origin: silent-corpus #1 (T-1874/75/76/77) and #2 (T-1879) — see L-397.
Each consumer re-implemented the scan, so T-1850's migration left
every inline reader returning zero for migrated arcs.
Public API (all functions assume PROJECT_ROOT is set):
arc_tasks_with_arc_id <slug>     → T-IDs whose `arc_id:` matches slug

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `.tasks/active/` | reads |
| `.tasks/completed/` | reads |

## Used By (3)

| Component | Relationship |
|-----------|-------------|
| `lib/arc.sh` | calls |
| `agents/handover/handover.sh` | calls |
| `lib/evolution_log.sh` | calls |

---
*Auto-generated from Component Fabric. Card: `lib-arc_membership-sh.yaml`*
*Last verified: 2026-05-17*
