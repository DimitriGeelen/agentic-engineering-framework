---
id: T-1477
name: "T-1477: Stop using T-012 as commit task when it is closed (handover commit
  warning)"
description: >
  T-1477: Stop using T-012 as commit task when it is closed (handover commit warning)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/handover/handover.sh, 
      tests/unit/handover_t012_active_only.bats]
related_tasks: []
created: 2026-04-25T21:04:57Z
last_update: '2026-08-16T22:24:33Z'
date_finished: 2026-04-25T21:07:13Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:49Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 (no-signal); 
      F3=0 (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1477: T-1477: Stop using T-012 as commit task when it is closed (handover commit warning)

## Context

`agents/handover/handover.sh:_resolve_commit_task` checks for T-012 in BOTH
`active/` and `completed/`. T-012 (the original "Create handover agent" task)
has been completed since the framework was built; the check-completed branch
matches it and every handover commit carries "T-012" — but the pre-commit
hook then warns "Task T-012 is closed".

Fix: require T-012 to be in `active/`. If only in completed/, fall through
to "find any *handover* task" or "auto-create" branches, which were always
intended for that case.

## Acceptance Criteria

### Agent
- [x] handover.sh's T-012 check requires the task to be in `.tasks/active/`
- [x] When T-012 is closed, fall through to existing handover-task lookup or auto-create
- [x] `bash -n agents/handover/handover.sh` parses
- [x] Bats test covers both branches (T-012 in active → used; T-012 in completed only → fall-through)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

bash -n agents/handover/handover.sh
bats tests/unit/handover_t012_active_only.bats

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

### 2026-04-25T21:04:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1477-t-1477-stop-using-t-012-as-commit-task-w.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7670ee48
- **Timestamp:** 2026-06-02T14:57:45Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-25T21:07:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
