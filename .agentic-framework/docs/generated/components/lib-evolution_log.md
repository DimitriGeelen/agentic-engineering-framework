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

## Used By (3)

| Component | Relationship |
|-----------|-------------|
| `agents/task-create/update-task.sh` | called_by |
| `tests/unit/evolution_log_gate.bats` | called_by |
| `tests/unit/evolution_log_gate.bats` | tests_by |

---
*Auto-generated from Component Fabric. Card: `lib-evolution_log.yaml`*
*Last verified: 2026-05-04*
