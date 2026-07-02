---
id: T-654
name: "Add fw cron run command for CLI job triggering"
description: >
  Add fw cron run command for CLI job triggering

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [bin/fw]
related_tasks: []
created: 2026-03-28T15:38:18Z
last_update: '2026-06-11T22:24:26Z'
date_finished: 2026-03-28T15:40:26Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:26Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 1
      D3: 3
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=1 (body:log-or-error-line); D3=3 
      (body:component-discoverability); D4=0 (no-signal); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-654: Add fw cron run command for CLI job triggering

## Context

CLI complement to the Watchtower "Run Now" button. `fw cron run <job-id>` triggers a job immediately from the terminal.

## Acceptance Criteria

### Agent
- [x] `fw cron run <job-id>` resolves the command from registry and executes it
- [x] Exit code, stdout snippet, and duration are printed
- [x] `fw cron run` with no args or invalid id prints error with available job IDs
- [x] `fw cron list` aliases `fw cron status` for discoverability

## Verification

grep -q 'cron.*run' bin/fw
bin/fw cron help 2>&1 | grep -q 'run'

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

### 2026-03-28T15:38:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-654-add-fw-cron-run-command-for-cli-job-trig.md
- **Context:** Initial task creation

### 2026-03-28T15:40:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3801a1fa
- **Timestamp:** 2026-06-02T15:04:09Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw cron help 2>&1 | grep -q 'run'`
