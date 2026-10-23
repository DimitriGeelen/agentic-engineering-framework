# wm_tasks

> lib/wm_tasks.sh — the workflow-management (WM) task class (T-3537)

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/wm_tasks.sh`

## What It Does

lib/wm_tasks.sh — the workflow-management (WM) task class (T-3537)
── WHY THIS EXISTS ───────────────────────────────────────────────────────────
The task gate refuses every Write/Edit and every Bash command it cannot prove
is a read, whenever focus is null. Focus goes null at exactly the moment a task
closes. So the work that FOLLOWS a close, and the work that PRECEDES selecting
the next task, has no task it can run under and is structurally unreachable —
OBS-250, twelve-plus recorded instances, three in one day, one of which forced
a worker to file a whole task (T-3530) purely to run `git commit`.
Operator framing, 2026-09-28, which is the design and not just the motivation:
"Why is this rule in there? … we want to prevent rogue sabotage or unintended

---
*Auto-generated from Component Fabric. Card: `lib-wm_tasks.yaml`*
*Last verified: 2026-09-28*
