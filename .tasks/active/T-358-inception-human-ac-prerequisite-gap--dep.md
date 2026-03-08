---
id: T-358
name: "Inception: Human AC prerequisite gap — deployment steps missing"
description: >
  Human ACs assume code is already deployed but don't include deployment
  prerequisites. T-357 AC says 'run fw init in temp dir' but doesn't say
  'first brew upgrade fw'. The AC instruction process needs to account for
  deployment/distribution steps when the code under test is distributed via
  package manager (Homebrew), not just local dev. Additionally, human ACs
  should be self-contained runbooks — the human should be able to copy-paste
  and execute without asking "ok what do I need to do?" A good human AC
  includes: (1) prerequisite steps (deploy, upgrade, setup), (2) the test
  steps, (3) what to check, (4) expected output verbatim. If the human has
  to ask for clarification, the AC failed its purpose.

status: captured
workflow_type: inception
owner: human
horizon: next
tags: [governance, quality]
components: []
related_tasks: [T-357, T-325]
created: 2026-03-08T18:42:46Z
last_update: 2026-03-08T18:42:46Z
date_finished: null
---

# T-358: Inception: Human AC prerequisite gap — deployment steps missing

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
