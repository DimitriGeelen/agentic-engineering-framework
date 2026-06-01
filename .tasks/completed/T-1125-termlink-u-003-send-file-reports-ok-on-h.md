---
id: T-1125
name: "TermLink U-003: send-file reports ok on hub acceptance, not delivery — silent file loss"
description: >
  Inception: TermLink U-003: send-file reports ok on hub acceptance, not delivery — silent file loss

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-12T08:19:54Z
last_update: 2026-04-13T06:23:19Z
date_finished: 2026-04-12T11:03:00Z
---

# T-1125: TermLink U-003: send-file reports ok on hub acceptance, not delivery — silent file loss

## Problem Statement

`termlink remote send-file` returns `ok:true` based on hub acceptance,
not end-to-end delivery to the receiver's inbox. ring20-manager sent 3
files to .107 — all returned ok:true, but none arrived. Files were
silently lost because the receiver had event-only sessions. ring20-manager
fell back to PTY inject. Origin: T-046 RCA on .109.

## Assumptions

- A1: send-file success = hub acceptance, not receiver delivery (CONFIRMED)

## Exploration Plan

1. Confirm send-file semantics via ring20-manager's T-046 RCA evidence (DONE)
2. Document the caveat in CLAUDE.md §TermLink Integration (DONE — T-1128)
3. Create pickup for TermLink upstream (DONE — P-013)

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN:** Document the caveat, create upstream pickup, record learning.
**OUT:** Implementing fix — this is TermLink repo's responsibility.

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
- send-file ok:true confirmed as hub acceptance, not end-to-end delivery
- Silent file loss is reproducible (ring20-manager sent 3 files, none arrived)
- Fix belongs in TermLink upstream (no framework arch changes)

**NO-GO if:**
- send-file actually does verify delivery and the loss had a different cause
- The hub-acceptance semantics are intentional and documented

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO

**Rationale:** send-file's ok:true semantics are misleading and cause silent data loss. ring20-manager sent 3 files to .107 -- all returned ok:true, none arrived. The receiver had event-only sessions (no inbox processing). This is a TermLink upstream issue -- the fix is to either return delivery confirmation or at minimum document the hub-acceptance semantics clearly. Pickup P-013 delivered to /opt/termlink.

**Evidence:**
- ring20-manager sent 3 files to .107, all returned ok:true, zero arrived
- Receiver had event-only sessions -- files silently lost
- ring20-manager fell back to PTY inject as workaround
- CLAUDE.md already updated with send-file caveat (T-1128)
- Learning L-006 recorded and shared cross-agent via pickup P-015

## Decisions

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: send-file's ok:true semantics are misleading and cause silent data loss. ring20-manager sent 3 files to .107 -- all returned ok:true, none arrived. The receiver had e...

**Date**: 2026-04-12T11:03:00Z
## Decision

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: send-file's ok:true semantics are misleading and cause silent data loss. ring20-manager sent 3 files to .107 -- all returned ok:true, none arrived. The receiver had e...

**Date**: 2026-04-12T11:03:00Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-12T08:20:13Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T11:03:00Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: send-file's ok:true semantics are misleading and cause silent data loss. ring20-manager sent 3 files to .107 -- all returned ok:true, none arrived. The receiver had e...

### 2026-04-12T11:03:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
