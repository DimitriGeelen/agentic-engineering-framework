# arc_membership_agent_surfaces

> T-1879 (T-NEW-14): silent-corpus #2 sweep — agent-side surfaces must read both `arc_id:` frontmatter (T-1849 canonical, T-1850 migrated) AND legacy `arc:<slug>` tag.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/arc_membership_agent_surfaces.bats`

## What It Does

T-1879 (T-NEW-14): silent-corpus #2 sweep — agent-side surfaces must read
both `arc_id:` frontmatter (T-1849 canonical, T-1850 migrated) AND legacy
`arc:<slug>` tag.
Sites under test:
- lib/evolution_log.sh task_has_arc_membership()
- lib/evolution_log.sh find_arc_tasks_without_evolution_log()
- agents/task-create/update-task.sh check_evolution_log() — via integration
- agents/handover/handover.sh current-arc task count — via integration
Sibling to T-1874/T-1875/T-1876/T-1877 (web + CLI + audit).

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [evolution_log](/docs/generated/lib-evolution_log) | tests | Detection helper for the T-1717 Q4 rigidity-vs-evolution pattern (T-1718 implementation). Mirrors lib/inception_recommendation.sh (T-1716) shape exactly: detection helper extracted so it can be tested without spinning up update-task.sh. |
| [update-task](/docs/generated/agents-task-create-update-task) | tests | Task Update Agent - Status transitions with auto-triggers |
| [handover](/docs/generated/agents-handover-handover) | tests | Handover Agent - Mechanical Operations |
| [evolution_log](/docs/generated/lib-evolution_log) | calls | Detection helper for the T-1717 Q4 rigidity-vs-evolution pattern (T-1718 implementation). Mirrors lib/inception_recommendation.sh (T-1716) shape exactly: detection helper extracted so it can be tested without spinning up update-task.sh. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-arc_membership_agent_surfaces.yaml`*
*Last verified: 2026-05-17*
