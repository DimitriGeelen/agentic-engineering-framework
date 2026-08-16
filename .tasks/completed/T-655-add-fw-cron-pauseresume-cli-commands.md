---
id: T-655
name: "Add fw cron pause/resume CLI commands"
description: >
  Add fw cron pause/resume CLI commands

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [bin/fw]
related_tasks: []
created: 2026-03-28T15:40:52Z
last_update: '2026-08-16T22:25:36Z'
date_finished: 2026-03-28T15:43:35Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:26Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 1
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=1 (body:log-or-error-line); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:36Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 1
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=1 (body:log-or-error-line); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-655: Add fw cron pause/resume CLI commands

## Context

CLI equivalents of the Watchtower Pause/Resume buttons. Updates registry YAML status field and regenerates the crontab.

## Acceptance Criteria

### Agent
- [x] `fw cron pause <job-id>` sets status to paused in registry and regenerates crontab
- [x] `fw cron resume <job-id>` sets status to active in registry and regenerates crontab
- [x] Both commands print confirmation message with job name
- [x] Invalid job-id prints error with available IDs

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     Examples:
       python3 -c "import yaml; yaml.safe_load(open('path/to/file.yaml'))"
       curl -sf http://localhost:3000/page
       grep -q "expected_string" output_file.txt
-->

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

### 2026-03-28T15:40:52Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-655-add-fw-cron-pauseresume-cli-commands.md
- **Context:** Initial task creation

### 2026-03-28T15:43:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e787a224
- **Timestamp:** 2026-06-02T15:04:09Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
