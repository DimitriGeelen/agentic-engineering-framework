---
id: T-563
name: "OpenClaw comparative: extension SDK design — what enables 80+ extensions"
description: >
  Dispatch to OpenClaw eval agent: What makes 80+ extensions possible? Minimal surface
  area for a working extension? Extension isolation (one bad extension doesnt crash
  system)? Contributor DX? Is there a pattern for making our framework extensible
  by other projects? Write findings. Review with human.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-03-23T17:17:44Z
last_update: '2026-06-11T22:24:24Z'
date_finished: 2026-03-28T09:32:09Z
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

# T-563: OpenClaw comparative: extension SDK design — what enables 80+ extensions

## Problem Statement

Compare OpenClaw's extension SDK (80+ extensions) vs our agent/hook model. See `docs/reports/T-563-extension-sdk-design.md`.

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made (NO-GO — governance, not extensibility)

## Go/No-Go Criteria

**GO if:** Need community extensions. **NO-GO if:** Extensions should be governed (validated).

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

### 2026-03-27T19:26:18Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-28T09:32:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f717020a
- **Timestamp:** 2026-06-02T15:03:35Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
