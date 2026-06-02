---
id: T-565
name: "OpenClaw comparative: monitoring and observability vs audit/watchtower"
description: >
  Dispatch to OpenClaw eval agent: How does OpenClaw observe running agents, detect failures, surface health? Compare to our audit/checkpoint/cron approach and Watchtower UI. What can we learn for our monitoring stack? Write findings. Review with human.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-23T17:17:49Z
last_update: 2026-03-28T09:31:47Z
date_finished: 2026-03-28T09:31:47Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-565: OpenClaw comparative: monitoring and observability vs audit/watchtower

## Problem Statement

Compare OpenClaw's observability (health probes, metrics, process registry) vs our audit/watchtower approach. See `docs/reports/T-565-monitoring-observability.md`.

## Assumptions

1. OpenClaw's real-time monitoring may be superior — INVALIDATED (different architecture)
2. Our audit-based approach may have blind spots — VALIDATED (T-583 addresses the gap)

## Exploration Plan

1. Inventory OpenClaw observability (6 layers) — DONE
2. Inventory our observability (10 layers) — DONE
3. Gap analysis — DONE

## Technical Constraints

N/A — comparative analysis only.

## Scope Fence

**IN:** Comparative analysis of monitoring approaches
**OUT:** Implementing new monitoring (T-583 already covers that)

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made (NO-GO — T-583 already captures the adoptable pattern)

## Go/No-Go Criteria

**GO if:**
- OpenClaw has monitoring we demonstrably lack and need

**NO-GO if:**
- Our compliance-based approach is more comprehensive for our use case (validated)

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

### 2026-03-27T19:25:05Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-28T09:31:47Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7f8268dc
- **Timestamp:** 2026-06-02T15:03:36Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
