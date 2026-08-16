---
id: T-1242
name: "Restore 239 learnings lost in T-1239 commit — learnings.yaml overwritten"
description: >
  Restore 239 learnings lost in T-1239 commit — learnings.yaml overwritten

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-13T20:17:44Z
last_update: '2026-08-16T22:24:26Z'
date_finished: 2026-04-13T20:20:35Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:43Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 3
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=3 (body:fw-recall-or-memory-link);
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:26Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 3
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=3 (body:fw-recall-or-memory-link);
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1242: Restore 239 learnings lost in T-1239 commit — learnings.yaml overwritten

## Context

Commit 5d90f655 (T-1239 completion) overwrote learnings.yaml from 239→3 entries.
Restored from ea1e41af (last good state). Root cause: add-learning rewrites entire file.

## Acceptance Criteria

### Agent
- [x] learnings.yaml restored to >= 239 entries
- [x] Bugfix-learning audit check passes

## Verification

python3 -c "import yaml; d=yaml.safe_load(open('.context/project/learnings.yaml')); n=len(d.get('learnings',[])); print(f'{n} learnings'); exit(0 if n >= 239 else 1)"

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

### 2026-04-13T20:17:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1242-restore-239-learnings-lost-in-t-1239-com.md
- **Context:** Initial task creation

### 2026-04-13T20:20:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d04edafc
- **Timestamp:** 2026-06-02T14:56:09Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
