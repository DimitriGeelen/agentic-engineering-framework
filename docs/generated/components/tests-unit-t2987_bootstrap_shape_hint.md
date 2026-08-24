# t2987_bootstrap_shape_hint

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2987_bootstrap_shape_hint.bats`

## What It Does

T-2987: the task gate advertises an unblock command it then blocks when redirected.
Reported from a fresh consumer project: focus pointed at a completed T-001, the gate
blocked, and its message said to run `fw work-on T-XXX`. The agent ran exactly that —
with the output redirected — and got the byte-identical message back. Nothing in it
said the redirect was the cause, so the agent retyped and looped.
The exemption at check-active-task.sh:194/:227 is guarded by has_bash_write_pattern,
which classifies the WHOLE command line while the exemption is about ONE command in
it. A `>` anywhere — on an unrelated chained command, or just capturing the bootstrap
command's own output — voids it for the bootstrap command too.
The guard is deliberate (:213-222 argues for failing toward blocking; L-547/T-2834

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-active-task](/docs/generated/agents-context-check-active-task) | calls | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [check-active-task](/docs/generated/agents-context-check-active-task) | tests | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2987_bootstrap_shape_hint.yaml`*
*Last verified: 2026-08-14*
