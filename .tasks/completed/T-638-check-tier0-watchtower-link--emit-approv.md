---
id: T-638
name: "check-tier0 Watchtower link — emit approval page URL in Tier 0 block message"
description: >
  check-tier0 Watchtower link — emit approval page URL in Tier 0 block message

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/context/check-tier0.sh]
related_tasks: []
created: 2026-03-27T10:28:12Z
last_update: '2026-08-16T22:25:36Z'
date_finished: 2026-03-27T11:23:09Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:26Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:36Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal);
      F3=0 (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-638: check-tier0 Watchtower link — emit approval page URL in Tier 0 block message

## Context

T-636 Phase 1 deliverable. When check-tier0.sh blocks a command, it currently only shows `./bin/fw tier0 approve` (CLI). Should also show the Watchtower /approvals URL so the human can approve in browser. Spike 3 identified this as the highest-value change (~10 lines). Research: docs/reports/T-636-unified-approval-experience.md

## Acceptance Criteria

### Agent
- [x] check-tier0.sh block message includes Watchtower /approvals URL
- [x] URL uses dynamic hostname + port detection (same pattern as lib/review.sh)
- [x] Both CLI and Watchtower options shown (not replacing CLI path)

## Verification

grep -q '/approvals' agents/context/check-tier0.sh

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-03-27T10:28:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-638-check-tier0-watchtower-link--emit-approv.md
- **Context:** Initial task creation

### 2026-03-27T11:23:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8b2ce6f0
- **Timestamp:** 2026-06-02T15:04:03Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#2 (Agent)** — URL uses dynamic hostname + port detection (same pattern as lib/review.sh)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/review.sh in: URL uses dynamic hostname + port detection (same pattern as lib/review.sh)`
