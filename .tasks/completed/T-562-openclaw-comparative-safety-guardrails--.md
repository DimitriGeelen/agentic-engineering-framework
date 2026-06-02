---
id: T-562
name: "OpenClaw comparative: safety guardrails — rate limiting, dedup, runaway prevention"
description: >
  Dispatch to OpenClaw eval agent: Investigate rate limiting, deduplication (idempotency keys), max-consecutive-same-tool detection. What safety patterns have no equivalent in our framework? How do they prevent runaway agents? Compare to our budget-gate.sh. Whats their blast radius containment for tool execution? Write findings. Review with human.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-23T17:17:41Z
last_update: 2026-03-28T09:31:40Z
date_finished: 2026-03-28T09:31:40Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-562: OpenClaw comparative: safety guardrails — rate limiting, dedup, runaway prevention

## Problem Statement

Compare OpenClaw's safety guardrails (rate limiting, dedup, runaway prevention) vs ours. See `docs/reports/T-562-safety-guardrails.md`.

## Assumptions

1. OpenClaw may have safety patterns we lack — INVALIDATED (different architecture)
2. Our budget gate is insufficient — INVALIDATED (comprehensive for our model)
3. Dedup/rate limiting is needed — INVALIDATED (single-agent, sequential)

## Exploration Plan

1. Inventory OpenClaw safety mechanisms — DONE (7 mechanisms)
2. Inventory our safety mechanisms — DONE (10 mechanisms)
3. Gap analysis — DONE (our framework is more comprehensive for our use case)

## Technical Constraints

N/A — comparative analysis only.

## Scope Fence

**IN:** Comparative gap analysis
**OUT:** Implementing new guardrails

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made (NO-GO — our framework is more comprehensive)

## Go/No-Go Criteria

**GO if:**
- OpenClaw has safety patterns we demonstrably lack

**NO-GO if:**
- Architectural differences make the comparison non-applicable (validated)

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

### 2026-03-27T19:23:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-28T09:31:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-76e7d432
- **Timestamp:** 2026-06-02T15:03:35Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
