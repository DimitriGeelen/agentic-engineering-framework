---
id: T-369
name: "Make fabric subsystem inference configurable"
description: >
  Add .fabric/subsystem-rules.yaml support so non-framework projects can define type/subsystem
  inference rules. register.sh checks this file BEFORE the hardcoded case statement,
  falls through to existing patterns if no rules file. See R-3 in fabric silent-degradation
  analysis.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: [fabric, portability]
components: [agents/fabric/lib/register.sh]
related_tasks: []
created: 2026-03-08T22:27:49Z
last_update: '2026-08-16T22:25:29Z'
date_finished: 2026-03-08T22:57:07Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:19Z'
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

# T-369: Make fabric subsystem inference configurable

## Context

R-3 from fabric silent-degradation analysis. register.sh type/subsystem inference is hardcoded to framework paths.

## Acceptance Criteria

### Agent
- [x] register.sh checks .fabric/subsystem-rules.yaml BEFORE hardcoded case statements
- [x] Rules use fnmatch patterns with type and subsystem fields
- [x] Falls through to existing inference if no rules file or no match
- [x] Shell syntax validates

## Verification

grep -q "subsystem-rules.yaml" agents/fabric/lib/register.sh
bash -n agents/fabric/lib/register.sh

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

### 2026-03-08T22:27:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-369-make-fabric-subsystem-inference-configur.md
- **Context:** Initial task creation

### 2026-03-08T22:34:14Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-08T22:57:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7b5f4d3e
- **Timestamp:** 2026-06-02T15:02:25Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — register.sh checks .fabric/subsystem-rules.yaml BEFORE hardcoded case statements
  - **AC-verify-mismatch** (narrow, heuristic) — `path=fabric/subsystem-rules.yaml in: register.sh checks .fabric/subsystem-rules.yaml BEFORE hardcoded case statements`
