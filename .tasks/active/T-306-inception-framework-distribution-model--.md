---
id: T-306
name: "Inception: framework distribution model — split vs self-contained"
description: >
  The current shared tooling model has the framework repo serving two roles: (1) self-hosting development project using its own governance, (2) live tool consumed by other projects. This creates version mingling — other projects execute live agents but hold frozen copies of CLAUDE.md, settings.json, seeds, templates. Half the project runs at init-time version, half at current version. This inception explores: how to create a clean distribution boundary between the self-hosting dev repo and what other projects consume. Constraint: the framework MUST remain self-hosting (it develops itself using its own tooling). The dev repo stays. The question is how other projects get a clean, versioned, non-entangled copy. Options include: versioned releases, vendored distribution, clean CLI separation. Related research: docs/reports/T-294-framework-onboarding-portable-bootstrap.md (Area 1, DX comparison). Source: T-294 dialogue — user identified split model as architecturally problematic.

status: captured
workflow_type: inception
owner: human
horizon: next
tags: []
components: []
related_tasks: [T-294]
created: 2026-03-04T16:41:57Z
last_update: 2026-03-04T16:41:57Z
date_finished: null
---

# T-306: Inception: framework distribution model — split vs self-contained

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
