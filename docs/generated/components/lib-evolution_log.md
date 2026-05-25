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

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [update-task](/docs/generated/agents-task-create-update-task) | called_by | Task Update Agent - Status transitions with auto-triggers |
| [evolution_log_gate](/docs/generated/tests-unit-evolution_log_gate) | called_by | TODO: describe what this component does |
| [evolution_log_gate](/docs/generated/tests-unit-evolution_log_gate) | tests_by | TODO: describe what this component does |
| [arc_membership_agent_surfaces](/docs/generated/tests-unit-arc_membership_agent_surfaces) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-evolution_log.yaml`*
*Last verified: 2026-05-04*
