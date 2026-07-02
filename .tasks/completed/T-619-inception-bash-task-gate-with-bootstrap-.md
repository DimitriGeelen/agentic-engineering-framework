---
id: T-619
name: "Inception: Bash task gate with bootstrap allowlist"
description: >
  check-active-task only gates Write|Edit, not Bash. Agent can bypass task gate via
  echo/cat/sed to write files. Bootstrap problem: fw context init and fw task create
  need Bash before any task exists. Investigate allowlist approach. From T-614 investigation.

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-03-25T20:17:29Z
last_update: '2026-06-11T22:24:25Z'
date_finished: 2026-03-28T17:09:07Z
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

# T-619: Inception: Bash task gate with bootstrap allowlist

## Problem Statement

**Superseded by T-630.** check-active-task only gates Write/Edit, not Bash. T-630 already completed comprehensive inception research covering Bash + Agent/TaskCreate + TermLink bypass paths. 5 spikes, 7920 Bash invocations analyzed, GO recommendation. Research artifact: `docs/reports/T-619-bash-task-gate.md` (references T-630).

## Assumptions

Validated by T-630: Safe-command allowlist (27 patterns) achieves <0.5% FP rate against real session data.

## Exploration Plan

Covered by T-630's 5 spikes. See `docs/reports/T-630-universal-task-gate.md`.

## Technical Constraints

Covered by T-630 research.

## Scope Fence

**Superseded.** T-630 covers Bash + Agent/Task + TermLink — strictly superset of T-619.

## Acceptance Criteria

### Agent
- [x] Problem statement validated (superseded by T-630)
- [x] Assumptions tested (T-630: 7920 invocations, <0.5% FP)
- [x] Recommendation written with rationale (T-630 GO, 3 build tasks)

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read the research artifact and recommendation in this task
  2. Evaluate go/no-go criteria against findings
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-XXX go|no-go --rationale "your rationale"`
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:** T-630 research validates the approach (validated — GO with 3 build tasks)

**NO-GO if:** T-630 found insurmountable issues (not the case)

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Recommendation

**Recommendation:** GO
**Rationale:** cjheck still needed

## Decisions

**Decision**: GO

**Rationale**: cjheck still needed

**Date**: 2026-03-28T17:09:07Z
## Decision

**Decision**: GO

**Rationale**: cjheck still needed

**Date**: 2026-03-28T17:09:07Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-27T17:48:41Z — status-update [task-update-agent]
- **Change:** horizon: now → next

### 2026-03-28T09:36:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-28T17:09:07Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** cjheck still needed

### 2026-03-28T17:09:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-190a9633
- **Timestamp:** 2026-06-02T15:03:56Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
