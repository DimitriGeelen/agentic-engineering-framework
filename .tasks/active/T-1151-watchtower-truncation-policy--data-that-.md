---
id: T-1151
name: "Watchtower truncation policy — data that flows into permanent records must NEVER be truncated at display layer"
description: >
  Inception: Watchtower truncation policy — data that flows into permanent records must NEVER be truncated at display layer

status: captured
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-12T11:08:23Z
last_update: 2026-04-12T11:08:23Z
date_finished: null
---

# T-1151: Watchtower truncation policy — data that flows into permanent records must NEVER be truncated at display layer

## Problem Statement

Watchtower truncates data at the display layer ([:200], [:197], [:500]) without distinguishing display-only fields from fields that flow into permanent records. When `rationale_hint` (pre-fills approval textarea) was truncated to 200 chars, the human clicking approve recorded a permanently truncated decision rationale in the task file. This is a class of bug: any Watchtower field that pre-fills a form that writes to disk must not be truncated. T-1091 fixed the inception detail page, but the approvals page (T-1150) had the same cap. Need a structural policy + audit of all truncation sites.

## Assumptions

- A1: There are two categories of truncation in Watchtower: display-only (safe) vs write-through (unsafe)
- A2: An invariant test can grep for `[:` patterns near form fields to catch new violations

## Exploration Plan

1. Audit all truncation sites in web/blueprints/ (already done: 20+ sites found)
2. Classify each as display-only or write-through
3. Propose structural enforcement (test or code pattern)

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
