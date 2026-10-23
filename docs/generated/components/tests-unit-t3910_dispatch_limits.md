# t3910_dispatch_limits

> T-3910 — operator ruling 2026-10-06: sub-agents run as TermLink workers, never through the vendor harness's own dispatcher (FW_DISPATCH_LIMIT defaults to 0), and TermLink dispatch is capped at TERMLINK_MAX_WORKERS (default 5) concurrent…

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3910_dispatch_limits.bats`

## What It Does

T-3910 — operator ruling 2026-10-06: sub-agents run as TermLink workers, never
through the vendor harness's own dispatcher (FW_DISPATCH_LIMIT defaults to 0),
and TermLink dispatch is capped at TERMLINK_MAX_WORKERS (default 5) concurrent
workers per project, raised only situationally on the operator's say-so.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3910_dispatch_limits.yaml`*
*Last verified: 2026-10-05*
