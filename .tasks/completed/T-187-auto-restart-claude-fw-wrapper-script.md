---
id: T-187
name: "Auto-restart: claude-fw wrapper script"
description: >
  From T-179 GO. Create bin/claude-fw wrapper script that runs claude, then checks
  for .context/working/.restart-requested signal file on exit. If found (and <5 min
  old), auto-restarts with claude -c. If stale, removes and exits. Includes --no-restart
  flag to opt out.

status: work-completed
workflow_type: build
owner: claude-code
horizon:
tags: []
related_tasks: []
created: 2026-02-19T07:39:56Z
last_update: '2026-08-16T22:24:47Z'
date_finished: 2026-02-19T07:41:19Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:01Z'
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
  - ts: '2026-08-16T22:24:47Z'
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

# T-187: Auto-restart: claude-fw wrapper script

## Context

Component 2 of T-179 auto-restart. Wrapper script that monitors the `.restart-requested` signal file from T-186.

## Acceptance Criteria

- [x] `bin/claude-fw` wrapper script exists and is executable
- [x] Runs `claude` with all passed arguments
- [x] On exit, checks for `.context/working/.restart-requested` signal file
- [x] Restarts with `claude -c` if signal is fresh (<5 min)
- [x] Ignores stale signals (>5 min old)
- [x] Supports `--no-restart` flag to disable auto-restart

## Verification

test -x /opt/999-Agentic-Engineering-Framework/bin/claude-fw
grep -q "restart-requested" /opt/999-Agentic-Engineering-Framework/bin/claude-fw
grep -q "\-\-no-restart" /opt/999-Agentic-Engineering-Framework/bin/claude-fw

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

### 2026-02-19T07:39:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-187-auto-restart-claude-fw-wrapper-script.md
- **Context:** Initial task creation

### 2026-02-19T07:41:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9e8f08da
- **Timestamp:** 2026-06-02T15:00:14Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
