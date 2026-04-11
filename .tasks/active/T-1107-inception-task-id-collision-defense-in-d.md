---
id: T-1107
name: "Inception: task-ID collision defense-in-depth — globally unique IDs or URL namespacing"
description: >
  Follow-up to T-1106 (Watchtower port bleed + cross-project task-ID collision). T-1106's Option D (identity-endpoint check before URL emission) closes the primary bleed-through, but leaks remain when a URL is shared with a second client (QR code scanned later; bookmark hit after Watchtower restart on a different project). This inception explores defense-in-depth: (1) make task IDs globally unique (prefix with project slug, e.g., '025/T-434' vs '999/T-434'); OR (2) namespace URL paths with project ('/proj/025/inception/T-434'); OR (3) embed project identifier in QR payload and have Watchtower /inception/T-XXX reject when the path project doesn't match the served project. Evaluate backwards-compat cost, consumer-project migration burden, QR lifetime, and interaction with T-885 port registry. Scope fence: NO build, NO schema lock. Deliverable: path recommendation with evidence from T-1106 RCA and audit of historical task-ID collisions across consumer projects. Related: T-1106, T-885, T-1105, T-1100.

status: captured
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-11T14:34:33Z
last_update: 2026-04-11T14:34:33Z
date_finished: null
---

# T-1107: Inception: task-ID collision defense-in-depth — globally unique IDs or URL namespacing

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

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
