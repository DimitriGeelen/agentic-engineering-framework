---
id: T-991
name: "Fix web test failures — update monkeypatch paths after subprocess_utils refactor"
description: >
  Fix web test failures — update monkeypatch paths after subprocess_utils refactor

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-07T08:51:22Z
last_update: '2026-08-16T22:25:45Z'
date_finished: 2026-04-07T09:43:10Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:34Z'
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
  - ts: '2026-08-16T22:25:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-991: Fix web test failures — update monkeypatch paths after subprocess_utils refactor

## Context

tasks.py was refactored to use `web.subprocess_utils.run_fw_command` instead of direct `subprocess.run`. TestSubprocessStderr monkeypatches the old path `web.blueprints.tasks.subprocess.run` which now fails with ImportError.

## Acceptance Criteria

### Agent
- [x] TestSubprocessStderr tests pass after monkeypatch path update
- [x] CSRF tests fixed — /api/ paths skip CSRF by design, tests updated
- [x] Footer version test fixed — no longer hardcodes v1.0.0
- [x] terminal.py/terminal/ package conflict resolved — PTY manager in __init__.py
- [x] All web tests pass (142/142, 0 failures)

## Verification

cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest web/test_app.py -x -q 2>&1 | tail -5

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

### 2026-04-07T08:51:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-991-fix-web-test-failures--update-monkeypatc.md
- **Context:** Initial task creation

### 2026-04-07T09:43:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7a193378
- **Timestamp:** 2026-06-02T15:06:06Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
