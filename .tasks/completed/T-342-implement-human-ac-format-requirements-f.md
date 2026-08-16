---
id: T-342
name: "Implement human AC format requirements from T-325"
description: >
  Implement human AC format requirements from T-325

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/task-create/update-task.sh]
related_tasks: []
created: 2026-03-08T09:43:49Z
last_update: '2026-08-16T22:25:28Z'
date_finished: 2026-03-08T09:45:50Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:19Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:28Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal);
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-342: Implement human AC format requirements from T-325

## Context

Implements GO decision from T-325 inception. See `docs/reports/T-325-human-ac-handoff-quality.md`.

## Acceptance Criteria

### Agent
- [x] CLAUDE.md has "Human AC Format Requirements" section with Steps/Expected/If-not rules
- [x] Task template `.tasks/templates/default.md` has actionable Human AC guidance
- [x] `update-task.sh` emits WARN when human ACs lack Steps blocks at partial-complete

## Verification

grep -q "Human AC Format Requirements" CLAUDE.md
grep -q "Steps:" .tasks/templates/default.md
grep -q "Steps" agents/task-create/update-task.sh

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

### 2026-03-08T09:43:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-342-implement-human-ac-format-requirements-f.md
- **Context:** Initial task creation

### 2026-03-08T09:45:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-afe06e4d
- **Timestamp:** 2026-06-02T15:02:15Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
