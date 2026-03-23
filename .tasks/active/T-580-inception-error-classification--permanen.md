---
id: T-580
name: "Inception: Error classification — permanent vs transient separation in healing loop"
description: >
  OpenClaw classifies delivery errors as permanent (chat not found, bot blocked — move to failed/) vs transient (network, 5xx — retry with backoff). This prevents wasting retries on unrecoverable failures. Our healing agent classifies errors by type (code, dependency, environment, design, external) but has no permanent/transient separation — it suggests retry for ALL failures including ones that can never succeed. Investigate: add permanent/transient markers to patterns.yaml entries, healing agent should skip retry suggestions for permanent errors, auto-classify based on error pattern history (same error 3+ times = likely permanent). Research source: docs/reports/T-549-openclaw-value-extraction.md (P6: multi-provider failover with error classification), .context/working/round2-T-016.md on OpenClaw eval project (error classification section). OpenClaw source: src/delivery/delivery-queue.ts (permanent error detection), src/agents/auth-profiles.ts (billing/auth error classification for provider rotation). Related: T-562 (safety guardrails), agents/healing/ (our healing loop implementation).

status: captured
workflow_type: inception
owner: agent
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-03-23T21:09:57Z
last_update: 2026-03-23T21:09:57Z
date_finished: null
---

# T-580: Inception: Error classification — permanent vs transient separation in healing loop

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
