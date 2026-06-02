---
id: T-1122
name: "TermLink U-002: no hub-level inbox — cannot push files when zero sessions registered"
description: >
  Inception: TermLink U-002: no hub-level inbox — cannot push files when zero sessions registered

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-12T08:05:17Z
last_update: 2026-04-13T06:23:18Z
date_finished: 2026-04-12T11:02:51Z
---

# T-1122: TermLink U-002: no hub-level inbox — cannot push files when zero sessions registered

## Problem Statement

`termlink send-file` requires a target session. When the receiving machine
has zero registered TermLink sessions (e.g., no Claude Code or shell session
is actively using TermLink), files cannot be delivered. ring20-manager (.109)
reported this during T-046 RCA: it tried to send G-005 and U-001/U-002
files to this machine but couldn't target a session.

**For whom:** Any cross-machine file delivery where the receiver may be idle.
**Why now:** ring20-manager reported as U-002 alongside U-001 (TLS cert).

**Proposed fix (from ring20-manager):** Hub-level inbox — files are stored
at the hub and delivered when a session registers. Like email: the mailbox
exists even when the user isn't logged in.

**Workaround:** SSH + scp (bypasses TermLink entirely).

## Assumptions

- A1: send-file currently requires an active session target (needs code verification)
- A2: Hub process persists between sessions, so it could hold files (likely true)

## Scope Fence

**IN:** Cross-project pickup to /opt/termlink for upstream design.
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
- send-file requires active session target confirmed (documented in T-1126 protocol)
- Hub process persists between sessions (can hold queued files)
- Pickup P-012 already delivered to /opt/termlink for upstream tracking

**NO-GO if:**
- Hub-level inbox adds unacceptable complexity to TermLink (scope creep)
- Persistent sessions (T-1135) make this moot (always a session to target)

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** DEFER (pending T-1135 outcome)

**Rationale:** If T-1135 (persistent TermLink agent sessions) ships, every project will always have an active session to target. This makes hub-level inbox less urgent -- there's always "someone home" to receive files. However, hub-level inbox is still valuable for edge cases (machine rebooting, between session respawns). Recommend: let T-1135 ship first, then reassess whether U-002 is still needed.

**Evidence:**
- ring20-manager reported U-002 during T-046 RCA -- files couldn't be sent when no sessions registered
- T-1135 (persistent sessions) was GO-recommended today with cross-agent coordination
- Persistent sessions solve the primary use case (always a target session)
- Hub-level inbox would handle the gap between persistent session death and respawn
- Pickup P-012 already delivered to /opt/termlink, T-1124 created from pickup processing

## Decisions

**Decision**: GO

**Rationale**: Recommendation: DEFER (pending T-1135 outcome)

Rationale: If T-1135 (persistent TermLink agent sessions) ships, every project will always have an active session to target. This makes hub-level inb...

**Date**: 2026-04-12T11:02:50Z
## Decision

**Decision**: GO

**Rationale**: Recommendation: DEFER (pending T-1135 outcome)

Rationale: If T-1135 (persistent TermLink agent sessions) ships, every project will always have an active session to target. This makes hub-level inb...

**Date**: 2026-04-12T11:02:50Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-12T09:27:47Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T11:02:50Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: DEFER (pending T-1135 outcome)

Rationale: If T-1135 (persistent TermLink agent sessions) ships, every project will always have an active session to target. This makes hub-level inb...

### 2026-04-12T11:02:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b2969864
- **Timestamp:** 2026-06-02T14:55:19Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
