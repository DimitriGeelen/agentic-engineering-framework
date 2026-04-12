---
id: T-1125
name: "TermLink U-003: send-file reports ok on hub acceptance, not delivery — silent file loss"
description: >
  Inception: TermLink U-003: send-file reports ok on hub acceptance, not delivery — silent file loss

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-12T08:19:54Z
last_update: 2026-04-12T08:20:13Z
date_finished: null
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

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

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

### 2026-04-12T08:20:13Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
