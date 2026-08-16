---
id: T-368
name: "Add fabric drift check to fw audit"
description: >
  In agents/audit/audit.sh, add a check that runs fw fabric drift and warns if unregistered
  source files exist matching watch patterns. Severity: warning not failure. Closes
  the feedback loop so empty fabric is surfaced during routine audits. See R-2 in
  fabric silent-degradation analysis.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: [fabric, audit]
components: [C-004]
related_tasks: []
created: 2026-03-08T22:27:38Z
last_update: '2026-08-16T22:25:29Z'
date_finished: 2026-03-08T22:57:06Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:19Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=0 (no-signal); D2=4 (body:fw-audit-or-doctor); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:29Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=0 (no-signal); D2=4 (body:fw-audit-or-doctor); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-368: Add fabric drift check to fw audit

## Context

R-2 from fabric silent-degradation analysis. Adds fabric drift detection to the structure section of fw audit.

## Acceptance Criteria

### Agent
- [x] Drift check added to structure section of audit.sh
- [x] Uses watch-patterns.yaml to find unregistered files
- [x] Severity is warn (not fail)
- [x] Gracefully skips if no watch-patterns.yaml exists

## Verification

grep -q "Fabric drift" agents/audit/audit.sh
grep -q "watch-patterns.yaml" agents/audit/audit.sh

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

### 2026-03-08T22:27:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-368-add-fabric-drift-check-to-fw-audit.md
- **Context:** Initial task creation

### 2026-03-08T22:30:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-08T22:57:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f745bdd7
- **Timestamp:** 2026-06-02T15:02:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
