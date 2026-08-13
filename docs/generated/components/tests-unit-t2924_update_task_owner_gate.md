# t2924_update_task_owner_gate

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2924_update_task_owner_gate.bats`

## What It Does

T-2924 — `fw task update --owner` must validate against the owner enum.
Raised by 832 on the DM rail: their tree practises `agent` x304 while the copy
they vendored names `human`/`claude-code`, and they asked which is
authoritative before their BPMN compiler starts emitting owners into task
files. Measuring the answer here surfaced the actual defect.
`update-task.sh` validates `--type` (is_valid_type) and `--horizon`
(is_valid_horizon) and did NOT validate `--owner` — the one sibling of three
left open. T-2674 closed the CREATE side (create-task.sh:203) and the update
path was never given the same treatment, so any string was written verbatim
while Watchtower's dropdowns whitelist the enum.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2924_update_task_owner_gate.yaml`*
*Last verified: 2026-08-11*
