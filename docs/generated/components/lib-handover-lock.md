# handover-lock

> handover-lock.sh — the budget-critical auto-handover's re-entry lock (T-3917, G-110).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/handover-lock.sh`

## What It Does

handover-lock.sh — the budget-critical auto-handover's re-entry lock (T-3917, G-110).
checkpoint.sh (T-136) holds .context/working/.handover-in-progress while it runs
the auto-handover, so a second PostToolUse call does not start a second one.
Before T-3917 the lock was the literal "1", removed only on the normal path:
any kill mid-handover (the claude-fw terminator's SIGTERM, a hook timeout)
stranded it, and every later auto-handover was skipped SILENTLY — measured
stale for ~4 months on AEF's own host and ~163 days on ring20-manager's.
Now the lock records "<epoch> <pid>", and ONE predicate decides staleness for
both the writer (checkpoint.sh) and the reporter (fw doctor):
- the writer's PID is no longer running, or

---
*Auto-generated from Component Fabric. Card: `lib-handover-lock.yaml`*
*Last verified: 2026-10-06*
