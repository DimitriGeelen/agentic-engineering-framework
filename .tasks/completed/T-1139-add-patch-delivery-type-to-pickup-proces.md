---
id: T-1139
name: "Add patch-delivery type to pickup processor — enable cross-project patch sharing"
description: >
  Inception: Add patch-delivery type to pickup processor — enable cross-project patch
  sharing

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-12T09:32:41Z
last_update: '2026-08-16T22:24:23Z'
date_finished: 2026-04-12T11:04:02Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:40Z'
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
  - ts: '2026-08-16T22:24:23Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1139: Add patch-delivery type to pickup processor — enable cross-project patch sharing

## Problem Statement

`fw pickup process` only accepts 4 envelope types: bug-report, learning, feature-proposal, pattern.
Cross-project patch deliveries (type `patch-delivery`) are rejected. Today, 010-termlink sent
two patches (P-015 portable date, P-016 session concerns) -- both rejected.

Patch delivery is a legitimate cross-project communication type that requires different
handling than the existing types: patches need code review + inception, not just task creation.

## Assumptions

- A1: patch-delivery is distinct from feature-proposal (patches include specific file changes, not just ideas)
- A2: Processing a patch-delivery should create an inception task (not a build task) since patches need review
- A3: The fix is a ~5-line addition to lib/pickup.sh (add case to validation + processing logic)

## Exploration Plan

1. Read lib/pickup.sh to understand the type validation and processing logic (DONE)
2. Design patch-delivery handling: create inception task with patch details in description

## Scope Fence

**IN:** Add patch-delivery type to pickup processor.
**OUT:** Automatic patch application, merge tooling, diff visualization.

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- patch-delivery is a real use case (CONFIRMED -- 2 rejected today from 010-termlink)
- Fix is minimal (add to validation allowlist + processing case)
- Creates inception task for review (not auto-applying patches)

**NO-GO if:**
- Patches should always go through manual file delivery, not pickup system

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO

**Rationale:** Two patches from 010-termlink were rejected today because `patch-delivery` isn't a valid pickup type. Cross-project patch sharing is a natural extension of the pickup system. The fix adds `patch-delivery` to the validation allowlist in lib/pickup.sh and creates inception tasks (not build tasks) since patches need code review before adoption.

**Evidence:**
- P-015 (portable date helpers) rejected: `Invalid type: patch-delivery`
- P-016 (session concerns check) rejected: same
- Both contain legitimate patches that we manually incepted as T-1134 and T-1136
- Fix: ~10 lines in lib/pickup.sh (2 validation sites + 1 processing case)
- Processing creates inception task with patch details, ensuring governance

## Decisions

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: Two patches from 010-termlink were rejected today because `patch-delivery` isn't a valid pickup type. Cross-project patch sharing is a natural extension of the pickup...

**Date**: 2026-04-12T11:04:02Z
## Decision

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: Two patches from 010-termlink were rejected today because `patch-delivery` isn't a valid pickup type. Cross-project patch sharing is a natural extension of the pickup...

**Date**: 2026-04-12T11:04:02Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-12T09:33:53Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T11:04:02Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Two patches from 010-termlink were rejected today because `patch-delivery` isn't a valid pickup type. Cross-project patch sharing is a natural extension of the pickup...

### 2026-04-12T11:04:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f0eb620b
- **Timestamp:** 2026-06-02T14:55:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
