# evolution_log

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/evolution_log.sh`

## What It Does

lib/evolution_log.sh
Detection helper for the T-1717 Q4 rigidity-vs-evolution pattern
(T-1718 implementation). Mirrors lib/inception_recommendation.sh
(T-1716) shape exactly: detection helper extracted so it can be
tested without spinning up update-task.sh.
Used by:
- agents/task-create/update-task.sh — check_evolution_log gate
- (future) agents/audit/audit.sh    — detective check for missing logs
- (future) lib/evolution_log.sh sweep mode
Public functions:

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [arc_membership-sh](/docs/generated/lib-arc_membership-sh) | calls | Canonical shell helper for arc-membership scans (T-1880 / T-NEW-15). Consolidates the union-of-`arc_id:`-frontmatter + legacy `arc:<slug>`-tag scan that previously lived inline in three shell consumers: lib/arc.sh, agents/handover/handover.sh, lib/evolution_log.sh. Companion to lib/arc_membership.py (which serves the Python/Flask side).  Public API (PROJECT_ROOT must be set):   arc_tasks_with_arc_id <slug>   → T-IDs whose `arc_id:` matches slug   arc_tasks_with_tag <tag>       → T-IDs whose `tags:` includes tag  Origin: silent-corpus #1 (T-1874/75/76/77) and #2 (T-1879) — captured as L-397. Each inline consumer had to be migrated independently after the T-1850 tags-to-arc_id storage migration; consolidation prevents the next storage-format migration from leaking through nine sites again. |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [update-task](/docs/generated/agents-task-create-update-task) | called_by | Task Update Agent - Status transitions with auto-triggers |
| [evolution_log_gate](/docs/generated/tests-unit-evolution_log_gate) | called_by | TODO: describe what this component does |
| [evolution_log_gate](/docs/generated/tests-unit-evolution_log_gate) | tests_by | TODO: describe what this component does |
| [arc_membership_agent_surfaces](/docs/generated/tests-unit-arc_membership_agent_surfaces) | tests_by | TODO: describe what this component does |
| [arc_membership_agent_surfaces](/docs/generated/tests-unit-arc_membership_agent_surfaces) | called_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-evolution_log.yaml`*
*Last verified: 2026-05-04*
