---
id: T-1345
name: "Pickup: Codify RPC resilience-tier taxonomy + version skew enforcement (Tier-A
  opaque vs Tier-B typed) (from termlink)"
description: >
  Auto-created from pickup envelope. Source: termlink, task T-1071. Type: feature-proposal.

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: [C-004, agents/task-create/create-task.sh, 
      tests/unit/task_id_race.bats]
related_tasks: []
created: 2026-04-20T07:46:36Z
last_update: '2026-06-11T22:23:46Z'
date_finished: 2026-04-22T09:42:21Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:46Z'
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

# T-1345: Pickup: Codify RPC resilience-tier taxonomy + version skew enforcement (Tier-A opaque vs Tier-B typed) (from termlink)

## Problem Statement

Duplicate of T-1311 (canonical). Both cite termlink source T-1071 (topic: Codify RPC resilience-tier taxonomy + version skew). Pickup dedup missed the collision.

## Assumptions

1. T-1311 exists with same termlink source — TRUE
2. No new information here — TRUE

## Exploration Plan

None — confirmed duplicate via source-task-ID cross-check.

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

## Acceptance Criteria

### Agent
- [x] Problem statement validated (T-1345 cites termlink T-1071; T-1311 cites termlink T-1071)
- [x] Assumptions tested (duplicate confirmed by source-task ID)
- [x] Recommendation written with rationale (DEFER — close as duplicate; keep T-1311)

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** DEFER (close as duplicate)

**Rationale:** T-1345 and T-1311 both cite termlink source task T-1071. Working this task would be redundant.

**Evidence:**
- T-1345 source: termlink T-1071
- T-1311 source: termlink T-1071 (canonical target)
- Pickup dedup missed the collision (G-046 class)

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

**Decision**: DEFER (duplicate of T-1311)

**Rationale**: Same termlink source task (T-1071) as T-1311. No independent research value.

**Date**: 2026-04-22T08:32:00Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-22T09:42:09Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-22T09:42:21Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-13fbf55b
- **Timestamp:** 2026-06-02T14:56:51Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
