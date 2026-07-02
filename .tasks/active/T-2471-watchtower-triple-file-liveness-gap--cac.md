---
id: T-2471
name: "fw serve port conflict — no auto-port-finding, requires manual trial-and-error"
description: >
  Inception: fw serve crashes on port conflict instead of auto-finding free port

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-07-02T19:16:39Z
last_update: 2026-07-02T19:32:00Z
date_finished:
target_blast_radius: 2
voi_score: 0.7
---

# T-2471: fw serve port conflict — no auto-port-finding, requires manual trial-and-error

## Problem Statement

**Symptom:** User requests Watchtower link. Agent emits `http://192.168.10.107:3000` (stale triple-file). URL doesn't respond. User tries `fw serve`: **"FUCKING BULLSHOT PORT 3000 IS TAKEN"**. User tries `fw serve --port 3001`: "Port 3001 is held by FOREIGN service". Manual trial-and-error required to find free port (3004 worked).

**Root Cause Analysis:**

1. **What happened:**
   - Watchtower process died (PID 1285653)
   - Triple files (`.context/working/watchtower.{pid,port,url}`) NOT cleaned up
   - Port 3000 occupied by legitimate other service (NOT a zombie)
   - Ports 3001, 3002, 3003 also occupied
   - `fw serve` crashes on conflict instead of scanning for free port
   - User forced into manual `--port` trial-and-error

2. **Why structurally allowed:**
   - **No auto-port-finding** — `fw serve` tries one port, fails, exits
   - **No health check before URL emission** — agent returns cached URL from dead Watchtower
   - **No PID validation** — triple file points to dead process, framework doesn't detect
   - **No stale triple-file cleanup** — dead Watchtower leaves garbage files
   - **User experience failure** — "just make it work" expectation violated

3. **Impact:**
   - User completely blocked until manual port scan
   - "FUCKING BULLSHOT" frustration level
   - Trust erosion: framework should auto-find port, not crash
   - Lost time on mechanical trial-and-error

**Structural Gap:** `fw serve` has no port-conflict resolution. Should scan 3000-3020, use first free port, update triple files with actual port. Playwright and other test services do this automatically — Watchtower should too.

## Assumptions

- User expectation: `fw serve` "just works" (finds free port automatically)
- Port range 3000-3020 is reasonable scan range
- Triple files should reflect ACTUAL running port, not desired port

## Open Questions

- **IW-1: Should fw serve scan for free port automatically?**
  confidence: 3 (high — user explicitly said "check playwright etc then use that, build this in the structural process")
  disposition: answered
  rationale: YES. User frustrated by manual trial-and-error. Playwright does this. Framework should too.

- **IW-2: What port range to scan?**
  confidence: 2 (medium — 3000-3020 is reasonable, configurable via FW_PORT_RANGE_MAX)
  disposition: answered
  rationale: Start at configured FW_PORT (default 3000), scan up to 3020. Most services don't occupy 20 consecutive ports.

- **IW-3: Should triple files be cleaned up on port conflict?**
  confidence: 3 (high — yes, dead PID means garbage triple files)
  disposition: answered
  rationale: If PID in triple file is dead OR cmdline mismatch, clear triple files immediately before port scan.

- **IW-4: Health check before URL emission?**
  confidence: 3 (high — yes, curl -sf before returning cached URL)
  disposition: answered
  rationale: Prevents returning URL to dead Watchtower. Cheap check, high value.

## Exploration Plan

1. **✅ Reproduced:** Port 3000-3003 occupied, user blocked, manual --port 3004 worked
2. **Design (10 min):**
   - **A (CRITICAL):** Auto-port-finding in `bin/watchtower.sh` — scan 3000-3020, use first free
   - **B (HIGH):** Health check in `fw watchtower url` — curl -sf before emit
   - **C (MEDIUM):** PID validation — check `/proc/$PID/cmdline` before trusting triple file
   - **D (MEDIUM):** Stale triple-file cleanup — clear if PID dead
3. **Prototype (30 min):** Implement A+B+C+D in `bin/watchtower.sh` + `lib/watchtower.sh`
4. **Test (10 min):** Occupy ports 3000-3003, run `fw serve`, verify it auto-finds 3004
5. **Document (5 min):** Update `fw serve --help` with auto-port-finding behavior

## Technical Constraints

- Port scan must be fast (<1s for 20 ports)
- Must not kill legitimate services on occupied ports
- Triple files must reflect ACTUAL port used, not desired port
- Health check must timeout quickly (1s max)

## Scope Fence

**IN scope:**
- Auto-port-finding for `fw serve` (scan 3000-3020)
- Health check before URL emission (`fw watchtower url`)
- PID validation before trusting triple files
- Stale triple-file cleanup

**OUT of scope:**
- Zombie Watchtower detection (port 3000 is NOT a zombie, user corrected this)
- systemd integration (T-1309 deferred)
- Cross-project port coordination
- Port conflict resolution for other services

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-2471`
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or command
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Auto-port-finding is implementable in <1 hour
- Health check + PID validation are cheap (<100 lines total)
- User experience improves (no manual --port trial-and-error)

**NO-GO if:**
- Port scanning is too slow (>2s)
- Implementation requires fundamental redesign
- Legitimate use cases for manual port specification are broken

## Verification

# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO

**Rationale:**

High-value usability fix. User explicitly requested: "check playwright etc then use that, build this in the structural process". Current behavior: `fw serve` crashes on port conflict, requires manual `--port` trial-and-error. Proposed fix: scan 3000-3020, use first free port, update triple files with actual port. Similar to Playwright/pytest auto-port-finding. Implementation cost: ~30min. User impact: eliminates "FUCKING BULLSHOT PORT IS TAKEN" frustration. Layered defense: auto-port-finding (A) + health check (B) + PID validation (C) + triple-file cleanup (D).

**Evidence:**

- User session S-2026-0702-2013: "wtahctower link please" (got stale URL), then "FUCKING BULLSHOT PORT 3000 IS TAKEN" (blocked)
- Manual --port scan: 3000/3001/3002/3003 occupied, 3004 worked
- Triple file: `.context/working/watchtower.pid` → `1285653` (dead PID)
- Port 3000 occupied by legitimate service (NOT zombie, user corrected)
- User feedback: "check playwright etc then use that, build this in the structural process"

**Candidates:**

- **A (CRITICAL):** Auto-port-finding — scan 3000-3020 in `bin/watchtower.sh`, use first free
- **B (HIGH):** Health check — curl -sf before URL emission in `fw watchtower url`
- **C (MEDIUM):** PID validation — check `/proc/$PID/cmdline` before trusting triple file
- **D (MEDIUM):** Stale triple-file cleanup — clear if PID dead or cmdline mismatch

**Recommended: A+B+C+D** (auto-port-finding is critical UX fix, rest are defensive)

## Decisions

<!-- No design decisions yet — straightforward implementation -->

## Decision

<!-- Filled at completion via: fw inception decide T-2471 go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion -->
