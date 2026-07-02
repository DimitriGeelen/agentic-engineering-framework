---
id: T-561
name: "OpenClaw comparative: tool call policy enforcement — runBeforeToolCallHook
  vs PreToolUse"
description: >
  Dispatch to OpenClaw eval agent: Compare OpenClaw runBeforeToolCallHook (tool loop
  detection, allowlists, profile policies) vs our PreToolUse hooks (check-active-task,
  check-tier0, budget-gate). What do they enforce that we dont? Is tool loop detection
  adoptable? How do they handle structural enforcement equivalent to nothing-without-a-task?
  Write findings to .context/working/. Review with human.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-03-23T17:17:39Z
last_update: '2026-06-11T22:24:24Z'
date_finished: 2026-03-28T09:32:07Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:24Z'
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

# T-561: OpenClaw comparative: tool call policy enforcement — runBeforeToolCallHook vs PreToolUse

## Problem Statement

Compare OpenClaw's runBeforeToolCallHook (tool loop detection, allowlists, profile policies) vs our PreToolUse hooks. See `docs/reports/T-561-tool-call-policy-enforcement.md`.

## Assumptions

1. OpenClaw may enforce things we don't — validated (loop detection is more robust)
2. Our enforcement model (tiers, tasks, inception) may be more principled — validated
3. Tool-level allow/deny is needed — INVALIDATED (redundant with our tier model)

## Exploration Plan

1. Compare enforcement mechanisms — DONE (gap analysis table)
2. Identify adoptable patterns — DONE (enhanced loop detection)
3. Identify non-adoptable patterns — DONE (per-tool policies, subagent isolation)

## Technical Constraints

- Our hooks are bash-based (PreToolUse), OpenClaw's are TypeScript
- T-594 already ported basic loop detection to TypeScript

## Scope Fence

**IN:** Comparative analysis of tool call enforcement mechanisms
**OUT:** Implementing changes (that's a build task)

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made (GO on enhanced loop detection)

## Go/No-Go Criteria

**GO if:**
- OpenClaw has enforcement we lack that would improve our framework
- Adoptable pattern has bounded implementation scope

**NO-GO if:**
- Our enforcement model is already more comprehensive
- Gaps are architectural (multi-tenant vs single-agent) and not applicable

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

### 2026-03-27T19:22:13Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-28T09:32:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-80e08e63
- **Timestamp:** 2026-06-02T15:03:35Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
