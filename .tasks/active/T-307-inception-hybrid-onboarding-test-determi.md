---
id: T-307
name: "Inception: hybrid onboarding test (deterministic + AI interpretation)"
description: >
  A pure deterministic script cannot interpret nuanced onboarding results (expected day-1 noise vs real failures, CLAUDE.md quality, UX clarity). Need hybrid approach: deterministic scaffolding (bash runs steps, captures output) + stochastic reasoning (AI interprets results). Follows CLI/Agent/Skill hierarchy: (1) CLI fw test-onboarding runs mechanical steps, (2) agents/onboarding-test/ with bash script + AGENT.md intelligence, (3) /test-onboarding skill for in-session use. This inception scopes: what checkpoints, what interpretation criteria, how to structure the AGENT.md, what 'good' looks like at each step. Evidence: T-294 live simulation found 9 issues that no deterministic script would have caught. L-029: dry-running onboarding catches bugs unit tests miss. Source: T-294 dialogue.

status: captured
workflow_type: inception
owner: human
horizon: next
tags: []
components: []
related_tasks: [T-294]
created: 2026-03-04T17:15:20Z
last_update: 2026-03-04T17:15:20Z
date_finished: null
---

# T-307: Inception: hybrid onboarding test (deterministic + AI interpretation)

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
