---
id: T-1216
name: "Fix vendored .agentic-framework missing watchtower.sh — pre-push audit errors
  on every push"
description: >
  Fix vendored .agentic-framework missing watchtower.sh — pre-push audit errors on
  every push

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-13T09:46:00Z
last_update: '2026-06-11T22:23:42Z'
date_finished: 2026-04-13T09:47:37Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:42Z'
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

# T-1216: Fix vendored .agentic-framework missing watchtower.sh — pre-push audit errors on every push

## Context

`lib/watchtower.sh` was created in T-1154 but never synced to `.agentic-framework/lib/`. The vendored
copy is what `fw upgrade` distributes to consumers AND what the framework's own `.agentic-framework/`
uses. `audit.sh` line 21 sources `$FRAMEWORK_ROOT/lib/watchtower.sh` — when FRAMEWORK_ROOT points to
`.agentic-framework/`, the file is missing, causing `No such file or directory` on every pre-push audit.

Root cause: `fw upgrade` syncs `lib/*.sh` to vendors, but the framework repo itself needs `fw upgrade .`
after adding new lib files. Two fixes needed:
1. Copy watchtower.sh to vendored location now
2. Ensure `fw upgrade` self-sync catches new files (already does — line 390 globs `lib/*.sh`)

## Acceptance Criteria

### Agent
- [x] `.agentic-framework/lib/watchtower.sh` exists and matches `lib/watchtower.sh`
- [x] Pre-push audit runs without `No such file or directory` error
- [x] All 11 local consumer projects upgraded with the new file

## Verification

test -f .agentic-framework/lib/watchtower.sh
diff -q lib/watchtower.sh .agentic-framework/lib/watchtower.sh

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

### 2026-04-13T09:46:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1216-fix-vendored-agentic-framework-missing-w.md
- **Context:** Initial task creation

### 2026-04-13T09:47:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b7b7ccd8
- **Timestamp:** 2026-06-02T14:55:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
