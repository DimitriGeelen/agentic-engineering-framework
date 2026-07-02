---
id: T-712
name: "Fix stale budget status after compact — clear .budget-status in post-compact-resume
  hook"
description: >
  Fix stale budget status after compact — clear .budget-status in post-compact-resume
  hook

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-03-29T13:12:12Z
last_update: '2026-06-11T22:24:28Z'
date_finished: 2026-03-29T13:13:52Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:28Z'
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

# T-712: Fix stale budget status after compact — clear .budget-status in post-compact-resume hook

## Context

After `/compact`, the budget gate reads stale `.budget-status` from the pre-compact session and immediately warns/blocks in the fresh session. Root cause: `post-compact-resume.sh` does not clear the cached budget state. Reported across 2-3 projects.

## Acceptance Criteria

### Agent
- [x] `post-compact-resume.sh` clears `.budget-status` on session recovery
- [x] `post-compact-resume.sh` clears `.budget-gate-counter` on session recovery
- [x] Vendored copy in `.agentic-framework/` updated
- [x] `bash -n` passes on modified script

## Verification

grep -q "budget-status" agents/context/post-compact-resume.sh
grep -q "budget-gate-counter" agents/context/post-compact-resume.sh
bash -n agents/context/post-compact-resume.sh

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

### 2026-03-29T13:12:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-712-fix-stale-budget-status-after-compact--c.md
- **Context:** Initial task creation

### 2026-03-29T13:13:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b1b802ed
- **Timestamp:** 2026-06-02T15:04:29Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
