---
id: T-579
name: "Inception: Idempotency/dedup layer — prevent hook re-entry and double task
  completion"
description: >
  OpenClaw has 4 dedup layers (inbound, persistent, global cache, agent-wait) using
  composite keys and TTL-based eviction. Our framework has zero dedup — if a task
  completion triggers twice (hook re-entry, retry), update-task.sh processes it again.
  Investigate: idempotency guard for update-task.sh (hash task_id+status+timestamp),
  hook re-entry prevention for PreToolUse/PostToolUse, and whether cron audit can
  double-fire. Research source: docs/reports/T-549-openclaw-architecture-mapping.md
  (Section 4: Key Patterns, deduplication), .context/working/round2-T-016.md on OpenClaw
  eval project (full gap analysis). OpenClaw source: src/gateway/server.impl.ts (idempotencyKeys
  map), src/delivery/delivery-queue.ts (persistent dedup with file locks). Related:
  T-562 (safety guardrails comparative task).

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-03-23T21:09:51Z
last_update: '2026-06-11T22:24:25Z'
date_finished: 2026-03-27T18:31:47Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-579: Inception: Idempotency/dedup layer — prevent hook re-entry and double task completion

## Problem Statement

OpenClaw has 4 dedup layers because it's a multi-tenant server with concurrent agents. Does our framework need similar dedup for hooks and task completion?

## Findings

- **update-task.sh** already has same-status guard (line 336): `"Status already — no change"`. Double completion is a no-op.
- **Hooks** are synchronous shell scripts — Claude Code calls them one at a time. Re-entry is architecturally impossible.
- **Cron audit** generates reports (write-only). Double-firing overwrites output harmlessly.
- **Root cause**: OpenClaw needs 4 dedup layers because it's multi-tenant with concurrent agents. Our framework is single-agent, sequential. The concurrency that creates dedup problems doesn't exist here.

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested — all 4 disproved (single-agent architecture)
- [x] Recommendation: DEFER (revised from NO-GO after multi-agent analysis)

### Human
- [x] [REVIEW] Review findings and approve no-go
  **Steps:**
  1. Read findings above
  2. Run: `fw inception decide T-579 no-go --rationale "your rationale"`
  **Expected:** Decision recorded
  **If not:** Ask for clarification

## Go/No-Go Criteria

**GO if:** Multi-agent execution lands (TermLink Phase 2+) and concurrent task operations observed
**NO-GO if:** Single-agent sequential architecture remains the only execution mode
**DEFER if:** Multi-agent is planned but not yet producing concurrent state mutations

## Multi-Agent Risk Assessment (added after human feedback)

The framework IS moving toward multi-agent:
- TermLink dispatch spawns concurrent workers sharing `.tasks/` and `.context/`
- `fw bus` designed for multi-agent result coordination
- T-571 (supervisor event loop) = explicit multi-agent orchestration

**Concrete risks when multi-agent lands:**
1. Two workers `fw task update T-XXX --status work-completed` simultaneously — no file locking
2. Concurrent episodic generation for same task — double-write
3. Concurrent `fw context focus` — last-write-wins on focus.yaml
4. Cron audit running while a worker modifies task state

**Current mitigation:** TermLink workers typically operate on DIFFERENT tasks (dispatched with specific task IDs). The bus system serializes results. But there's no structural guarantee.

**Revised recommendation: DEFER** — not needed today (single-agent), but add `flock`-based guards to `update-task.sh` when TermLink Phase 2 (parallel dispatch) ships. The trigger: first time two workers operate on the same task concurrently.

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Recommendation

**Recommendation:** DEFER
**Rationale:** DEFER full dedup until TermLink Phase 2 ships. Exception: fix bus.sh ID generation now — only component designed for multi-agent with race condition in core operation. Steelman found 16 surfaces but strawman showed zero incidents in 530 tasks. Reactive fix for the rest is 2 hours when real failure shape is known.

## Decisions

**Decision**: DEFER

**Rationale**: DEFER full dedup until TermLink Phase 2 ships. Exception: fix bus.sh ID generation now — only component designed for multi-agent with race condition in core operation. Steelman found 16 surfaces but strawman showed zero incidents in 530 tasks. Reactive fix for the rest is 2 hours when real failure shape is known.

**Date**: 2026-03-25T13:33:41Z
## Decision

**Decision**: DEFER

**Rationale**: DEFER full dedup until TermLink Phase 2 ships. Exception: fix bus.sh ID generation now — only component designed for multi-agent with race condition in core operation. Steelman found 16 surfaces but strawman showed zero incidents in 530 tasks. Reactive fix for the rest is 2 hours when real failure shape is known.

**Date**: 2026-03-25T13:33:41Z

## Updates

### 2026-03-25T12:20:00Z — inception-exploration [agent]
- **Action:** Investigated update-task.sh idempotency, hook re-entry, cron double-fire
- **Finding:** Same-status guard exists, hooks are synchronous, architecture is single-agent
- **Initial recommendation:** NO-GO

### 2026-03-25T12:25:00Z — human-feedback [agent]
- **Action:** Human challenged: "what if we go towards multi-agent execution?"
- **Revision:** TermLink dispatch already spawns concurrent workers. DEFER revised.

### 2026-03-25T12:40:00Z — steelman-strawman [agent]
- **Action:** Dispatched steelman (FOR) and strawman (AGAINST) agents
- **Steelman:** 16 race-condition surfaces, bus.sh most dangerous (designed for multi-agent, uses find|wc for IDs), flock costs 2ms
- **Strawman:** Zero incidents in 1589 commits/530 tasks, TermLink workers get separate task IDs, flock not on macOS (D4 violation)
- **Synthesis:** DEFER full dedup, but fix bus.sh now — only component designed for concurrent use with race condition in core ID generation
- **Decision:** Human chose DEFER with bus.sh exception

### 2026-03-25T12:15:54Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-25T13:33:41Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** DEFER full dedup until TermLink Phase 2 ships. Exception: fix bus.sh ID generation now — only component designed for multi-agent with race condition in core operation. Steelman found 16 surfaces but strawman showed zero incidents in 530 tasks. Reactive fix for the rest is 2 hours when real failure shape is known.

### 2026-03-27T18:31:47Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-febb44a2
- **Timestamp:** 2026-06-02T15:03:41Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
