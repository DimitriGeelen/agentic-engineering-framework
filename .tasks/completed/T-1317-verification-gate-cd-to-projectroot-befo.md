---
id: T-1317
name: "Verification gate cd to PROJECT_ROOT before eval (T-1044 fix from email-archive)"
description: >
  One-line fix in agents/task-create/update-task.sh:223 — add 'cd "$PROJECT_ROOT"
  && ' inside the eval subshell so verification commands resolve relative paths against
  PROJECT_ROOT regardless of caller CWD. Sibling to T-1316 inception. Email-archive
  proposal at docs/proposals/T-1316-from-email-archive-watchtower-verification-cwd.md.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-18T20:36:11Z
last_update: '2026-06-11T22:23:45Z'
date_finished: 2026-04-18T23:32:04Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1317: Verification gate cd to PROJECT_ROOT before eval (T-1044 fix from email-archive)

## Context

Sibling to inception T-1316 (pickup from email-archive T-1044). One-line fix to the verification subshell.

## Acceptance Criteria

### Agent
- [x] `agents/task-create/update-task.sh:223` evals verification commands inside `cd "$PROJECT_ROOT" && eval "$cmd"` subshell
- [x] Existing T-739 behaviour preserved (`unset TASKS_DIR CONTEXT_DIR _FW_PATHS_LOADED` still applied)
- [x] Bats regression test exercises a verification command using a relative path from a non-PROJECT_ROOT CWD
- [x] `bats tests/unit/update_task_verification.bats` passes
- [x] Existing tests still green (targeted suites: update_task.bats 15/15, update_task_verification.bats 2/2, lib_inception.bats 16/16, inception_decide_ac_tick.bats 10/10 — all pass post-T-1317)


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

grep -q 'cd "$PROJECT_ROOT" && eval' agents/task-create/update-task.sh
bats tests/unit/update_task_verification.bats

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

### 2026-04-18T20:36:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1317-verification-gate-cd-to-projectroot-befo.md
- **Context:** Initial task creation

### 2026-04-18T20:36:34Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-18T23:32:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** All Agent ACs satisfied; targeted bats suites green

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0d4c4a53
- **Timestamp:** 2026-06-02T14:56:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
