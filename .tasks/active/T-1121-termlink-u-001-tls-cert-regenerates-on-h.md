---
id: T-1121
name: "TermLink U-001: TLS cert regenerates on hub restart — breaks all client TOFU trust"
description: >
  Inception: TermLink U-001: TLS cert regenerates on hub restart — breaks all client TOFU trust

status: captured
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-12T08:04:30Z
last_update: 2026-04-12T08:04:30Z
date_finished: null
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
- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Recommendation written with rationale

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- [Criterion 1]
- [Criterion 2]

**NO-GO if:**
- [Criterion 1]
- [Criterion 2]

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

<!-- REQUIRED before fw inception decide. Write your recommendation here (T-974).
     Watchtower reads this section — if it's empty, the human sees nothing.
     Format:
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence from exploration)
     **Evidence:**
     - Finding 1
     - Finding 2
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
