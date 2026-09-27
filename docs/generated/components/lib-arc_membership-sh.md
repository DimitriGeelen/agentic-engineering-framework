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

| Component | Relationship | Description |
|-----------|--------------|-------------|
| `.tasks/active/` | reads | — |
| `.tasks/completed/` | reads | — |

## Used By (12)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [arc](/docs/generated/lib-arc) | calls | lib/arc.sh — Arc system (T-1653 Phase 1 / T-1661 / T-1848) |
| [handover](/docs/generated/agents-handover-handover) | calls | Handover Agent - Mechanical Operations |
| [evolution_log](/docs/generated/lib-evolution_log) | calls | Detection helper for the T-1717 Q4 rigidity-vs-evolution pattern (T-1718 implementation). Mirrors lib/inception_recommendation.sh (T-1716) shape exactly: detection helper extracted so it can be tested without spinning up update-task.sh. |
| [handover](/docs/generated/agents-handover-handover) | called_by | Handover Agent - Mechanical Operations |
| [arc_membership_shared](/docs/generated/tests-unit-arc_membership_shared) | tests_by | T-1880 (T-NEW-15): pin shared shell API for arc-membership scans. Sibling to tests/unit/arc_membership_agent_surfaces.bats (which pins consumer-site behaviour). This file pins the SHARED LIBRARY itself. |
| [audit_ctl_arc_tag_only_pattern](/docs/generated/tests-unit-audit_ctl_arc_tag_only_pattern) | called_by | T-1881 (T-NEW-16): pin the ctl-arc-tag-only-pattern audit check. |
| [audit_ctl_arc_tag_only_pattern](/docs/generated/tests-unit-audit_ctl_arc_tag_only_pattern) | tests_by | T-1881 (T-NEW-16): pin the ctl-arc-tag-only-pattern audit check. |
| [arc_membership_dual_id](/docs/generated/tests-unit-arc_membership_dual_id) | tests_by | tests/unit/arc_membership_dual_id.bats — T-1913 |
| [arc](/docs/generated/lib-arc) | called_by | lib/arc.sh — Arc system (T-1653 Phase 1 / T-1661 / T-1848) |
| [evolution_log](/docs/generated/lib-evolution_log) | called_by | Detection helper for the T-1717 Q4 rigidity-vs-evolution pattern (T-1718 implementation). Mirrors lib/inception_recommendation.sh (T-1716) shape exactly: detection helper extracted so it can be tested without spinning up update-task.sh. |
| [arc_membership_dual_id](/docs/generated/tests-unit-arc_membership_dual_id) | called_by | tests/unit/arc_membership_dual_id.bats — T-1913 |
| [arc_membership_shared](/docs/generated/tests-unit-arc_membership_shared) | called_by | T-1880 (T-NEW-15): pin shared shell API for arc-membership scans. Sibling to tests/unit/arc_membership_agent_surfaces.bats (which pins consumer-site behaviour). This file pins the SHARED LIBRARY itself. |

---
*Auto-generated from Component Fabric. Card: `lib-arc_membership-sh.yaml`*
*Last verified: 2026-05-17*
