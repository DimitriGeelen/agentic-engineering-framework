# push-state

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/push-state.sh`

## What It Does

lib/push-state.sh — T-3063 (leg 2 of T-3062)
Push outcomes, remembered across sessions.
WHY THIS EXISTS
The framework already counts unpushed commits at handover time (T-3025,
handover.sh). That counter fired correctly in four consecutive sessions and
printed `⚠ 7 commit(s) NOT pushed` every time, and every time it was ignored
— because the line reads *identically* at one commit five minutes old and at
seven commits across four failed pushes. A count is a snapshot. "Stuck" is a
property of history, and nothing was keeping any.
So this file keeps a little: how many consecutive sessions the push has

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [handover](/docs/generated/agents-handover-handover) | called_by | Handover Agent - Mechanical Operations |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `lib-push-state.yaml`*
*Last verified: 2026-09-03*
