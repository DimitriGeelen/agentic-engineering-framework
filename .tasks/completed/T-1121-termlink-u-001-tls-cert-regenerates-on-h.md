---
id: T-1121
name: "TermLink U-001: TLS cert regenerates on hub restart — breaks all client TOFU trust"
description: >
  Inception: TermLink U-001: TLS cert regenerates on hub restart — breaks all client TOFU trust

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-12T08:04:30Z
last_update: 2026-04-13T06:23:18Z
date_finished: 2026-04-12T11:02:43Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1121: TermLink U-001: TLS cert regenerates on hub restart — breaks all client TOFU trust

## Problem Statement

TermLink hub generates a new TLS certificate on every restart. All clients
that previously connected via TOFU (Trust On First Use) now reject the hub
because the fingerprint changed. Live evidence: this session tried
`termlink remote ping 192.168.10.109:9100` and got TOFU VIOLATION — the
.109 hub restarted since our last connection, invalidating the fingerprint
in `/root/.termlink/known_hubs`.

**For whom:** Every TermLink client on every machine that connects to a hub.
**Why now:** ring20-manager (.109) reported this as U-001 during T-046 RCA.
We independently confirmed it this session when trying to receive files.

**Proposed fix (from ring20-manager):** Persist the cert like T-933 persists
secrets — generate once, save to a known path (e.g., `/var/lib/termlink/hub.pem`),
reload on restart instead of regenerating.

## Assumptions

- A1: Hub cert is generated at startup, not persisted (CONFIRMED by TOFU violation)
- A2: Persisting cert to disk is straightforward (needs verification in TermLink codebase)

## Scope Fence

**IN:** Cross-project pickup to /opt/termlink for upstream fix.
**OUT:** Implementing the fix here — this is TermLink repo's responsibility.

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- TOFU violation confirmed independently (not just ring20-manager's report)
- Fix is scoped to TermLink upstream repo (no framework arch changes)
- Pickup P-011 already delivered to /opt/termlink for upstream tracking

**NO-GO if:**
- TOFU behavior is intentional/desirable for TermLink's security model
- Hub cert rotation is a feature, not a bug (some TOFU designs rotate deliberately)

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO

**Rationale:** Hub cert regeneration on restart is a clear defect — TOFU is useless if every restart invalidates trust. Independently confirmed this session (not just ring20-manager's report). Fix belongs in TermLink upstream (persist cert like T-933 persists secrets). Pickup P-011 already delivered. No framework changes needed.

**Evidence:**
- TOFU violation confirmed: `termlink remote ping 192.168.10.109:9100` returned fingerprint mismatch after hub restart
- ring20-manager independently reported same issue as U-001 during T-046 RCA
- Workaround exists (clear `known_hubs` entry) but is manual and per-client
- Proposed fix is minimal: persist cert to disk, reload on restart instead of regenerating
- Research artifact: `docs/reports/T-1121-termlink-tls-tofu.md`

## Decisions

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: Hub cert regeneration on restart is a clear defect — TOFU is useless if every restart invalidates trust. Independently confirmed this session (not just ring20-manager...

**Date**: 2026-04-12T11:02:43Z
## Decision

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: Hub cert regeneration on restart is a clear defect — TOFU is useless if every restart invalidates trust. Independently confirmed this session (not just ring20-manager...

**Date**: 2026-04-12T11:02:43Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-12T08:16:27Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T11:02:43Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Hub cert regeneration on restart is a clear defect — TOFU is useless if every restart invalidates trust. Independently confirmed this session (not just ring20-manager...

### 2026-04-12T11:02:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-def10721
- **Timestamp:** 2026-06-02T14:55:18Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
