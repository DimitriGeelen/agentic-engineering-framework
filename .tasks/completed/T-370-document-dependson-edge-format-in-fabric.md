---
id: T-370
name: "Document depends_on edge format in fabric skeleton card"
description: >
  Update skeleton card template in agents/fabric/lib/register.sh to include edge format
  hint: {target: <path>, type: calls|reads|writes|triggers|renders}. Without this,
  agents write plain string lists which traverse.sh silently ignores. See R-4 in fabric
  silent-degradation analysis.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: [fabric, documentation]
components: [agents/fabric/lib/register.sh]
related_tasks: []
created: 2026-03-08T22:27:59Z
last_update: '2026-08-16T22:25:29Z'
date_finished: 2026-03-08T22:57:08Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:20Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:29Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-370: Document depends_on edge format in fabric skeleton card

## Context

R-4 from fabric silent-degradation analysis. traverse.sh expects `{target: path, type: calls}` edges but the skeleton card shows bare `depends_on: []` with no format hint.

## Acceptance Criteria

### Agent
- [x] Skeleton card template includes depends_on format comment with target/type fields
- [x] Skeleton card template includes depended_by section
- [x] Fill-in hint mentions edge format

## Verification

grep -q "target:" agents/fabric/lib/register.sh
grep -q "calls|reads|writes|triggers|renders" agents/fabric/lib/register.sh
grep -q "depended_by" agents/fabric/lib/register.sh

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

### 2026-03-08T22:27:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-370-document-dependson-edge-format-in-fabric.md
- **Context:** Initial task creation

### 2026-03-08T22:28:47Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-08T22:57:08Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b88af102
- **Timestamp:** 2026-06-02T15:02:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
