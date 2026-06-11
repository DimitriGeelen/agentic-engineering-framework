---
id: T-1150
name: "RCA: recommendation text truncation in multiple surfaces — fix + inception
  for remediation"
description: >
  RCA: recommendation text truncation in multiple surfaces — fix + inception for remediation

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-12T11:05:48Z
last_update: '2026-06-11T22:23:41Z'
date_finished: 2026-04-12T11:09:13Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:41Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1150: RCA: recommendation text truncation in multiple surfaces — fix + inception for remediation

## Context

RCA: Watchtower approvals page truncates `rationale_hint` to 200 chars. This pre-fills the textarea. When human clicks approve, truncated text becomes the PERMANENT decision rationale in the task file. Root cause: approvals.py:145 `hint[:197] + "..."`. Also truncates `problem_excerpt` to 200 chars. Inception for structural remediation: need a policy that Watchtower NEVER truncates data that flows into permanent records.

## Acceptance Criteria

### Agent
- [x] rationale_hint no longer truncated in approvals.py
- [x] problem_excerpt remains truncated (display-only, not permanent)
- [x] Inception task created for structural remediation (truncation policy) — T-1151

## Verification

bash -c '! grep -q "hint\[:197\]" web/blueprints/approvals.py'
grep -q "NO truncation" web/blueprints/approvals.py

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

### 2026-04-12T11:05:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1150-rca-recommendation-text-truncation-in-mu.md
- **Context:** Initial task creation

### 2026-04-12T11:09:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-af4f85db
- **Timestamp:** 2026-06-02T14:55:30Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
