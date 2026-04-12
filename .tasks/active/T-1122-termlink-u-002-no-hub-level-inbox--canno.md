---
id: T-1122
name: "TermLink U-002: no hub-level inbox — cannot push files when zero sessions registered"
description: >
  Inception: TermLink U-002: no hub-level inbox — cannot push files when zero sessions registered

status: captured
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-12T08:05:17Z
last_update: 2026-04-12T08:05:17Z
date_finished: null
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
