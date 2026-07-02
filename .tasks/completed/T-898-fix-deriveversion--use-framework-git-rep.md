---
id: T-898
name: "Fix _derive_version — use framework git repo, not cwd"
description: >
  Fix _derive_version — use framework git repo, not cwd

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [bin/fw]
related_tasks: []
created: 2026-04-05T13:36:39Z
last_update: '2026-06-11T22:24:32Z'
date_finished: 2026-04-05T13:38:34Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:32Z'
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
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-898: Fix _derive_version — use framework git repo, not cwd

## Context

`_derive_version()` in `bin/fw` uses `git describe` without `-C`, so it derives version from the cwd's git repo, not the framework repo. When `fw upgrade` is run from a consumer project directory, it gets the consumer's version instead of the framework version. Found during T-897 — first upgrade round set sprechloop version to 1.0.15 instead of 1.4.603.

## Acceptance Criteria

### Agent
- [x] `_derive_version()` uses `git -C` to target the framework repo directory
- [x] Version is correct when running from a different directory

## Verification

grep -q '\-C.*BASH_SOURCE\|git -C' bin/fw

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

### 2026-04-05T13:36:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-898-fix-deriveversion--use-framework-git-rep.md
- **Context:** Initial task creation

### 2026-04-05T13:38:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f4c38da0
- **Timestamp:** 2026-06-02T15:05:31Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
