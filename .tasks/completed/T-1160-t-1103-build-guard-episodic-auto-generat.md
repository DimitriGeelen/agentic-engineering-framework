---
id: T-1160
name: "T-1103 build: Guard episodic auto-generation on partial-complete"
description: >
  T-1103 build: Guard episodic auto-generation on partial-complete

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/task-create/update-task.sh]
related_tasks: []
created: 2026-04-12T12:09:47Z
last_update: '2026-06-11T22:23:41Z'
date_finished: 2026-04-12T12:11:36Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:41Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1160: T-1103 build: Guard episodic auto-generation on partial-complete

## Context

Build from T-1103 GO decision. Episodic auto-trigger at update-task.sh fires unconditionally on `work-completed`, even when `PARTIAL_COMPLETE=true`. Fix: wrap episodic generation in `PARTIAL_COMPLETE` guard. See `docs/reports/T-1103-episodic-partial-rca.md`.

## Acceptance Criteria

### Agent
- [x] Episodic trigger guarded by `PARTIAL_COMPLETE` flag
- [x] Partial-complete tasks do NOT generate episodic on first `--status work-completed`
- [x] Full-complete tasks still generate episodic normally

## Verification

bash -c 'grep -B8 "generate-episodic.*TASK_ID" agents/task-create/update-task.sh | grep -q "PARTIAL_COMPLETE.*false"'

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

### 2026-04-12T12:09:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1160-t-1103-build-guard-episodic-auto-generat.md
- **Context:** Initial task creation

### 2026-04-12T12:11:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-411eaa49
- **Timestamp:** 2026-06-02T14:55:35Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `bash -c 'grep -B8 "generate-episodic.*TASK_ID" agents/task-create/update-task.sh | grep -q "PARTIAL_COMPLETE.*false"'`
