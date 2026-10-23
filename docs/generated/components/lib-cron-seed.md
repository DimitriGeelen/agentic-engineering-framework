# cron-seed

> lib/cron-seed.sh — T-3673

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/cron-seed.sh`

## What It Does

lib/cron-seed.sh — T-3673
Framework-owned cron jobs every consumer needs, merged into a consumer's
.context/cron-registry.yaml by `fw init` (fresh) and `fw upgrade` (existing).
Rules: add a job ONLY when no job with that id exists. Never overwrite, reorder
or rewrite an existing job — operator edits to a same-id job win. Commands use
bare `fw`; `fw cron generate` resolves it to the consumer's own fw path. The
flock name carries the project slug so two consumers on one host never share
a lock (the AEF registry's slug-less lock names are single-project only).

---
*Auto-generated from Component Fabric. Card: `lib-cron-seed.yaml`*
*Last verified: 2026-10-01*
