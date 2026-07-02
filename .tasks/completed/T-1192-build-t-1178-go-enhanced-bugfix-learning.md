---
id: T-1192
name: "Build T-1178 GO: enhanced bugfix-learning prompt + audit escalation (G-016)"
description: >
  Build T-1178 GO: enhanced bugfix-learning prompt + audit escalation (G-016)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-12T22:16:06Z
last_update: '2026-06-11T22:23:42Z'
date_finished: 2026-04-12T22:20:57Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:42Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=1 (body/components:prompt-incidental); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1192: Build T-1178 GO: enhanced bugfix-learning prompt + audit escalation (G-016)

## Context

T-1178 inception GO: 0% bugfix-learning coverage (G-016). Implement Options B + C: enhanced visual learning prompt in `update-task.sh` with pre-filled command and guidance questions, plus audit escalation from WARN to FAIL below 10%. Research: `docs/reports/T-1178-bugfix-learning-enforcement.md`.

## Acceptance Criteria

### Agent
- [x] `update-task.sh` learning prompt has visual box (bordered), pre-filled `fw fix-learned` command, and guidance questions
- [x] Audit check escalates to FAIL when bugfix-learning ratio < 10%
- [x] Vendored copies synced
- [x] Unit tests pass (15/15 update-task tests)
- [x] G-016 updated in concerns.yaml with resolution progress

## Verification

grep -q "LEARNING PROMPT" agents/task-create/update-task.sh
grep -q "fix-learned" agents/task-create/update-task.sh
grep -q "FAIL\|fail" agents/audit/audit.sh

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

### 2026-04-12T22:16:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1192-build-t-1178-go-enhanced-bugfix-learning.md
- **Context:** Initial task creation

### 2026-04-12T22:20:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f4f7df2f
- **Timestamp:** 2026-06-02T14:55:48Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
