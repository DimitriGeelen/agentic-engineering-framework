---
id: T-432
name: "Re-evaluate SKIP refactoring findings (27 items, score ≤4)"
description: >
  Re-evaluate 27 refactoring findings that scored ≤4 against the four directives. These were deprioritized in T-411 as cosmetic or low-impact. After DO and MAYBE phases complete, reassess whether: (a) any findings upgraded by new evidence, (b) any became moot from other refactoring, (c) any patterns emerged that change scoring. SKIP findings: S9 (inline template dup, 5), S11 (dir init, 5), S12 (shopt, 2), S14 (help text, 3), J5 (abort cleanup, 4), J7 (hardcoded colors, 4), J8 (DOM queries, 2), J9 (naming, 3), J10 (null checks, 4), J11 (magic numbers, 4), J12 (addEventListener, 2), P2 (logger naming, 3), P5 (handover parsing, 4), P6 (task caching, 3), P10 (magic numbers, 4), P12 (regex compile, 1), P13 (error context, 4), H5 (page headers, 3), H6 (table macro, 3), H8 (htmx boilerplate, 3), H9 (badge styling, 3), H12 (grid utils, 2), H13 (snippets, 2), H14 (form rows, 2), A1 (scanner wrapper, 3), A4 (stale backup, 3), A10 (directives drift, 4). Ref: docs/reports/T-411-refactoring-directive-scoring.md

status: captured
workflow_type: inception
owner: human
horizon: later
tags: [refactoring, quality, audit]
components: []
related_tasks: []
created: 2026-03-10T21:04:40Z
last_update: 2026-03-10T21:04:40Z
date_finished: null
---

# T-432: Re-evaluate SKIP refactoring findings (27 items, score ≤4)

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

- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- [Criterion 1]
- [Criterion 2]

**NO-GO if:**
- [Criterion 1]
- [Criterion 2]

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
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
