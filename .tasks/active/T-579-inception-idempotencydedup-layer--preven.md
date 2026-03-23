---
id: T-579
name: "Inception: Idempotency/dedup layer — prevent hook re-entry and double task completion"
description: >
  OpenClaw has 4 dedup layers (inbound, persistent, global cache, agent-wait) using composite keys and TTL-based eviction. Our framework has zero dedup — if a task completion triggers twice (hook re-entry, retry), update-task.sh processes it again. Investigate: idempotency guard for update-task.sh (hash task_id+status+timestamp), hook re-entry prevention for PreToolUse/PostToolUse, and whether cron audit can double-fire. Research source: docs/reports/T-549-openclaw-architecture-mapping.md (Section 4: Key Patterns, deduplication), .context/working/round2-T-016.md on OpenClaw eval project (full gap analysis). OpenClaw source: src/gateway/server.impl.ts (idempotencyKeys map), src/delivery/delivery-queue.ts (persistent dedup with file locks). Related: T-562 (safety guardrails comparative task).

status: captured
workflow_type: inception
owner: agent
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-03-23T21:09:51Z
last_update: 2026-03-23T21:09:51Z
date_finished: null
---

# T-579: Inception: Idempotency/dedup layer — prevent hook re-entry and double task completion

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
