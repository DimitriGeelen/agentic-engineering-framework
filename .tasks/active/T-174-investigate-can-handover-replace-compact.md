---
id: T-174
name: "Investigate: can handover replace compaction entirely?"
description: >
  Deep investigation (2-3 agents): Claude Code auto-compacts at ~180K tokens, summarizing prior context. But the framework already creates handovers that preserve context for session continuity. Questions: (1) What exactly does Anthropic's compaction step do? What information is preserved/lost? (2) Is compaction redundant given our handover system? (3) If we could forgo compaction, we'd gain ~20-30K usable tokens (safe zone up to ~160K with 20K reserved for handover routine). (4) What are the risks of disabling compaction — is it even possible to disable? (5) Could we configure compaction to use our handover as the summary source? This needs research into Claude Code internals and careful analysis of what compaction provides that handovers don't.

status: captured
workflow_type: inception
owner: claude-code
horizon: next
tags: []
related_tasks: []
created: 2026-02-18T18:24:39Z
last_update: 2026-02-18T18:24:39Z
date_finished: null
---

# T-174: Investigate: can handover replace compaction entirely?

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
