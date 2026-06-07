# audit_ctl030_completed_horizon_drift

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/audit_ctl030_completed_horizon_drift.bats`

## What It Does

T-2162 / CTL-030: completed/ stored-horizon drift detection
arc-009 horizon-axis-hardening Slice 3.
After T-2160 derives render-time `past` from _location, the stored
`horizon:` field on completed/ files is behaviorally irrelevant. T-2161
nulled the existing 1828-file pile. This rail catches future drift —
every task that closes carries `horizon: now/next/later` from its
active-state YAML until `bin/migrate-horizon-null-completed.sh` reruns.
Empty/absent/null/~ are LEGITIMATE (117 pre-frontmatter-template-era
files have no horizon field at all) — they must NOT trip this rail.

## Dependencies (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [completed-task-scan](/docs/generated/agents-audit-completed-task-scan) | calls | Single-pass scan of completed task files that checks for missing episodic summaries, missing research artifacts, and unchecked acceptance criteria |
| [active-task-scan](/docs/generated/agents-audit-active-task-scan) | calls | Single-pass scan of active task files that checks compliance, quality, research artifacts, ownership, and review queue status in one efficient pass |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | tests | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [completed-task-scan](/docs/generated/agents-audit-completed-task-scan) | tests | Single-pass scan of completed task files that checks for missing episodic summaries, missing research artifacts, and unchecked acceptance criteria |
| [active-task-scan](/docs/generated/agents-audit-active-task-scan) | tests | Single-pass scan of active task files that checks compliance, quality, research artifacts, ownership, and review queue status in one efficient pass |

---
*Auto-generated from Component Fabric. Card: `tests-unit-audit_ctl030_completed_horizon_drift.yaml`*
*Last verified: 2026-06-01*
