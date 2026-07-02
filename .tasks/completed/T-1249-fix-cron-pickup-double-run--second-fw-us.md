---
id: T-1249
name: "Fix cron pickup double-run — second fw uses bare path, fails in cron"
description: >
  Fix cron pickup double-run — second fw uses bare path, fails in cron

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-13T21:17:30Z
last_update: '2026-06-11T22:23:43Z'
date_finished: 2026-04-13T22:15:54Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:43Z'
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

# T-1249: Fix cron pickup double-run — second fw uses bare path, fails in cron

## Context

Cron generator only resolves the first `fw ` in a command to the full path.
The pickup `fw pickup process; sleep 30; fw pickup process` has a bare `fw` after the semicolon.
Fix: resolve ALL `fw ` occurrences in the command, not just the leading one.

## Acceptance Criteria

### Agent
- [x] Cron generator resolves all `fw ` occurrences in commands to full path
- [x] Generated crontab has full paths for both pickup invocations

## Verification

grep "pickup" /opt/999-Agentic-Engineering-Framework/.context/cron/agentic-audit.crontab | grep -v "^#" | python3 -c "import sys; line=sys.stdin.read(); exit(1 if ' fw ' in line else 0)"

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

### 2026-04-13T21:17:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1249-fix-cron-pickup-double-run--second-fw-us.md
- **Context:** Initial task creation

### 2026-04-13T22:15:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6df56213
- **Timestamp:** 2026-06-02T14:56:12Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
