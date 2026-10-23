# pid-alive

> lib/pid-alive.sh — the one zombie-aware pid liveness test (T-4306, T-4337).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/pid-alive.sh`

## What It Does

lib/pid-alive.sh — the one zombie-aware pid liveness test (T-4306, T-4337).
`kill -0` alone succeeds on a ZOMBIE (exited, never reaped by its parent),
so a bare `kill -0` reads a dead Watchtower as running. T-4306 fixed this in
bin/watchtower.sh; T-4337 moved the helper here so lib/watchtower.sh and
lib/watchtower-staleness.sh use the same test instead of bare `kill -0`.

---
*Auto-generated from Component Fabric. Card: `lib-pid-alive.yaml`*
*Last verified: 2026-10-21*
