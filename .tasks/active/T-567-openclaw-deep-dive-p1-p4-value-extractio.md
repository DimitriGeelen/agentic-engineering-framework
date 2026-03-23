---
id: T-567
name: "OpenClaw deep-dive: P1-P4 value extraction — request context, session keys, config reload, skills discovery"
description: >
  Dispatch to OpenClaw eval agent: Deep-dive P1-P4 patterns for adoption. P1: request-scoped context pattern implementation details. P2: session key derivation (300 LOC pure logic, src/routing/*.ts) — extract and assess. P3: config hot-reload (200 LOC, config-reload*.ts) — declarative reload rules. P4: skills discovery — frontmatter format, token-budget-aware prompt formatting (150 skill limit, 30K cap), three-tier layering. For each: code quality, portability, adoption effort. Write findings. Review with human.

status: captured
workflow_type: inception
owner: agent
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-03-23T17:18:02Z
last_update: 2026-03-23T17:18:02Z
date_finished: null
---

# T-567: OpenClaw deep-dive: P1-P4 value extraction — request context, session keys, config reload, skills discovery

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
