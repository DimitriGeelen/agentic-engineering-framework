---
id: T-137
name: Task template enforcement — require AC and Verification on creation
description: >
  create-task.sh generates tasks with placeholder AC and Verification sections that
  the agent never fills in. Sprechloop cycle 2: 11 tasks created as stubs, all completed
  without AC or Verification. Change: (1) create-task.sh should include a real AC
  section with at least one placeholder checkbox that must be edited, (2) include
  a Verification section with a comment explaining what to add, (3) update-task.sh
  should WARN (not block) when transitioning to started-work if AC section still has
  only placeholder text. Blocking is too aggressive — but warning makes the obligation
  visible.
status: work-completed
workflow_type: build
horizon:
owner: human
tags: []
related_tasks: []
created: 2026-02-17T23:49:42Z
last_update: '2026-08-16T22:24:30Z'
date_finished: 2026-02-18T06:17:04Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:30Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-137: Task template enforcement — require AC and Verification on creation

## Context

Sprechloop cycle 2: 11 tasks created as stubs, all completed without AC or Verification. The audit (T-135) now catches thin tasks after the fact, but prevention is better — make create-task.sh produce templates that prompt the agent to fill in real criteria.

## Acceptance Criteria

- [x] create-task.sh default template includes `## Acceptance Criteria` with placeholder checkbox
- [x] create-task.sh default template includes `## Verification` with comment examples
- [x] update-task.sh warns on started-work transition if AC has placeholder text
- [x] Warning does NOT block (warns only)

## Verification

# Default template has AC section with placeholder checkbox
grep -q 'Acceptance Criteria' agents/task-create/create-task.sh
# Default template has Verification section with example comments
grep -q '## Verification' agents/task-create/create-task.sh
# update-task.sh warns on placeholder AC
grep -q 'Replace with specific' agents/task-create/update-task.sh

## Updates

### 2026-02-17T23:49:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-137-task-template-enforcement--require-ac-an.md
- **Context:** Initial task creation

### 2026-02-18T00:05:18Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-18T06:17:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6e2b099b
- **Timestamp:** 2026-06-02T14:57:04Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
