# working-gitignore

> T-4231 — keep runtime state under .context/working/ out of a consumer's git.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/working-gitignore.sh`

## What It Does

T-4231 — keep runtime state under .context/working/ out of a consumer's git.
Hooks, doctor, audit, Watchtower and the budget gate write counters, locks,
pid/url files, cursors, logs and telemetry into .context/working/. The
framework repo ignores some of them in its ROOT .gitignore, which no consumer
inherits; `fw init` only wrote five names. So a fresh consumer's bootstrap
commit tracked .verb-counter/.verb-counter.lock/.budget-gate-counter, and the
rest showed up in the audit's uncommitted-changes rail on every run. Origin:
1023 msg cc1a5259 item 6 (their T-126/T-127 re-probe on vendored 1.8.10).
Deliberately NOT listed — these are records a project keeps in git:
.gate-bypass-log.yaml, feedback-stream.yaml, reviewer-overrides.yaml,

---
*Auto-generated from Component Fabric. Card: `lib-working-gitignore.yaml`*
*Last verified: 2026-10-21*
