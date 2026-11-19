# task-create-rules

> lib/task-create-rules.sh — the rules a new task must pass (T-5221, slice 2 of T-5212).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/task-create-rules.sh`

## What It Does

lib/task-create-rules.sh — the rules a new task must pass (T-5221, slice 2 of T-5212).
Lifted out of agents/task-create/create-task.sh so `fw task create` and
`fw task create-batch` validate by ONE rule set. Messages are byte-identical to the ones
create-task printed inline; each function prints to stderr and RETURNS 1 instead of
exiting, so the batch can check every entry before it refuses.
Needs lib/enums.sh (is_valid_type/horizon/owner) and lib/errors.sh (error); sources them
when the caller has not.
Public:
task_rule_name NAME                      T-555 template-placeholder names
task_rule_fields NAME TYPE HORIZON OWNER type, horizon (T-2160), owner (T-2674),

---
*Auto-generated from Component Fabric. Card: `lib-task-create-rules.yaml`*
*Last verified: 2026-11-18*
