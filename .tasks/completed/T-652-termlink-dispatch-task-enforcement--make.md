---
id: T-652
name: "TermLink dispatch task enforcement — make --task mandatory in fw termlink dispatch"
description: >
  T-630 GO build task 3: Make --task flag mandatory in fw termlink dispatch. Workers
  spawned without task reference have zero governance. Add task requirement + enforcement
  language to dispatch preamble. ~8 lines changed in lib/dispatch.sh. Related: T-630,
  T-650, T-651.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-28T09:45:53Z
last_update: '2026-08-16T22:25:36Z'
date_finished: 2026-03-28T09:48:20Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:26Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 1
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 1
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=1 (body:log-or-error-line); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=1 
      (body:hand-wired-dispatch); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:36Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 1
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=1 (body:log-or-error-line); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-652: TermLink dispatch task enforcement — make --task mandatory in fw termlink dispatch

## Context

T-630 GO build task 3. TermLink workers are full Claude Code sessions with zero inherited governance. Make `--task` mandatory.

## Acceptance Criteria

### Agent
- [x] `cmd_dispatch()` in `agents/termlink/termlink.sh` validates `--task` is provided
- [x] Missing `--task` produces clear error message
- [x] Vendored copy synced to `.agentic-framework/agents/termlink/`
- [x] `bash -n` passes on modified script

## Verification

bash -n agents/termlink/termlink.sh
grep -q 'Missing --task' agents/termlink/termlink.sh

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

### 2026-03-28T09:45:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-652-termlink-dispatch-task-enforcement--make.md
- **Context:** Initial task creation

### 2026-03-28T09:48:20Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1357f53d
- **Timestamp:** 2026-06-02T15:04:08Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
