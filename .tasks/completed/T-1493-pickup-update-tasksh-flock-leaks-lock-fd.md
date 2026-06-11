---
id: T-1493
name: "Pickup: update-task.sh flock leaks lock FD to dotnets VBCSCompiler daemon,
  blocking future fw task updates (from 003-NTB-ATC-Plugin)"
description: >
  Auto-created from pickup envelope. Source: 003-NTB-ATC-Plugin, task T-146. Type:
  bug-report.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [pickup, bug-report]
components: [agents/task-create/update-task.sh, lib/keylock.sh, 
      tests/unit/keylock_subshell_close.bats]
related_tasks: []
created: 2026-04-26T11:06:01Z
last_update: '2026-06-11T22:23:50Z'
date_finished: 2026-04-26T17:38:52Z
source_task_id_in_origin: T-146
source_project_in_origin: "003-NTB-ATC-Plugin"
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:50Z'
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

# T-1493: Pickup: update-task.sh flock leaks lock FD to dotnets VBCSCompiler daemon, blocking future fw task updates (from 003-NTB-ATC-Plugin)

## Context

`lib/keylock.sh` opens lock FDs (starting at 200) via `exec ${fd}>"$lock_file"` without `O_CLOEXEC`. Any child process spawned while a lock is held inherits the FD. When the child is a long-lived daemon (.NET's VBCSCompiler, sbt server, gradle daemon, etc.), the FD outlives the build that spawned it — blocking any later `flock` on the same key indefinitely.

**Real impact (P-015 / 003-NTB-ATC-Plugin / T-146):** Verification ran `dotnet build`. dotnet spawned VBCSCompiler. VBCSCompiler inherited fd 200 (the keylock FD). The subsequent active→completed status transition tried to re-acquire the lock — blocked forever until the user manually killed the daemon.

**Fix (a) from envelope:** Wrap verification execution in a subshell that closes the lock FDs before executing the user command. Implementation: add `keylock_subshell_close_cmd` helper to `lib/keylock.sh` that emits `exec N>&-` for every currently-held lock FD, and `eval` its output inside `run_verification_commands` before `eval "$cmd"`.

Out of scope: fix (c) watchdog (separate task if the FD-close fix proves insufficient).

## Acceptance Criteria

### Agent
- [x] `keylock_subshell_close_cmd` helper added to `lib/keylock.sh`, emits `exec N>&-` for every held FD
- [x] `run_verification_commands` in `agents/task-create/update-task.sh` evals the helper output inside the verification subshell BEFORE running the user command
- [x] Bats test: hold a lock, run `keylock_subshell_close_cmd`, verify it emits a close command for the held FD
- [x] Bats test: hold a lock, run a child that backgrounds and sleeps; with the close-cmd in the subshell, child does NOT inherit the FD (`lsof` check or fd-test)

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

bash -n lib/keylock.sh
bash -n agents/task-create/update-task.sh
bats tests/unit/keylock_subshell_close.bats

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

### 2026-04-26T11:06:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1493-pickup-update-tasksh-flock-leaks-lock-fd.md
- **Context:** Initial task creation

### 2026-04-26T17:37:05Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a46d5f31
- **Timestamp:** 2026-06-02T14:57:51Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-26T17:38:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
