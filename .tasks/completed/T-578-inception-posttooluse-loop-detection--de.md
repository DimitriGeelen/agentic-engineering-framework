---
id: T-578
name: "Inception: PostToolUse loop detection — detect and block repetitive failing
  tool calls"
description: >
  OpenClaw has 4-detector loop detection system (generic_repeat, known_poll_no_progress,
  ping_pong, global_circuit_breaker) using SHA256 hashing of canonicalized params
  + outcome tracking. Our framework has zero protection against agents calling the
  same failing command 50 times, burning context silently. Investigate: PostToolUse
  hook that hashes tool_name + params, tracks outcome hashes, warns at 5 repetitions,
  blocks at 10. Source: T-015 comparative analysis, OpenClaw tool-loop-detection.ts.

status: work-completed
workflow_type: inception
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-23T21:09:25Z
last_update: '2026-06-11T22:24:25Z'
date_finished: 2026-03-25T11:53:52Z
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

# T-578: Inception: PostToolUse loop detection — detect and block repetitive failing tool calls

## Problem Statement

An agent calling the same failing command 50 times burns context silently with zero detection. OpenClaw solved this with a 4-detector loop detection system. We need to investigate whether a PostToolUse loop detector is feasible for our hook architecture.

## Research Artifacts

- `docs/reports/T-549-openclaw-architecture-mapping.md` — Section 2: Agent Runtime, tool call flow
- `docs/reports/T-549-openclaw-design-patterns.md` — Tool policy patterns
- `/opt/openclaw-evaluation/.context/working/round2-T-015.md` — Full comparative analysis: tool call policy enforcement
- OpenClaw source: `src/agents/tool-loop-detection.ts` (4-detector implementation with SHA256 hashing)
- OpenClaw source: `src/agents/pi-tools.ts` (runBeforeToolCallHook integration point)
- Related framework: `agents/context/checkpoint.sh` (existing PostToolUse hook — potential integration point)
- Related framework: `agents/context/budget-gate.sh` (PreToolUse pattern to follow for blocking)

## Status: SUPERSEDED

Already built in T-594 (port loop detector to TypeScript). Production implementation at `lib/ts/src/loop-detect.ts` includes all 3 detectors:
- **generic_repeat**: same tool+params called N times (warn 5, block 10)
- **ping_pong**: alternating between two tool calls
- **no_progress**: same tool+params+result repeated

Shell wrapper: `agents/context/loop-detect.sh`. State: `.context/working/.loop-detect.json`.

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested (implementation already exists)
- [x] Recommendation written — superseded by T-594

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

**Decision**: SUPERSEDED

**Rationale**: Loop detection was independently built in T-586 (spike) and T-594 (production port) before this inception started. 3-detector TypeScript implementation with SHA256 hashing, warn/block thresholds, state persistence.

**Date**: 2026-03-25T12:00:00Z

## Updates

### 2026-03-25T11:52:15Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-25T12:00:00Z — superseded [agent]
- **Action:** Found existing implementation at lib/ts/src/loop-detect.ts (T-594)
- **Decision:** SUPERSEDED — no exploration needed

### 2026-03-25T11:53:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Superseded by T-594

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f4d3ff96
- **Timestamp:** 2026-06-02T15:03:41Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
