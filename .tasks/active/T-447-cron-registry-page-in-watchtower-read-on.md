---
id: T-447
name: "Cron registry page in Watchtower (read-only, Option A)"
description: >
  Cron registry page in Watchtower (read-only, Option A)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [watchtower, cron, observability]
components: []
related_tasks: []
created: 2026-03-12T06:13:28Z
last_update: 2026-03-12T06:13:28Z
date_finished: null
---

# T-447: Cron registry page in Watchtower (read-only, Option A)

## Context

Inception T-433 GO (Option A). See `docs/reports/T-433-cron-registry-inception.md`.
Read-only page: parse `/etc/cron.d/agentic-*`, display jobs with schedule, last run, result.

## Acceptance Criteria

### Agent
- [x] Blueprint `web/blueprints/cron.py` created
- [x] Template `web/templates/cron.html` created
- [x] Parses `/etc/cron.d/agentic-*` files for job metadata
- [x] Shows: job name, schedule, last run time, last result (pass/warn/fail)
- [x] Calculates and shows next run time from cron expression
- [x] Nav entry added (Govern > Cron in shared.py NAV_GROUPS)
- [x] Page loads at `/cron` (200 OK, 10 jobs rendered)
- [x] Blueprint registered in `web/blueprints/__init__.py`

### Human
- [ ] [REVIEW] Cron registry page renders correctly and is useful
  **Steps:**
  1. Open http://localhost:3000/cron in browser
  2. Verify all 10 scheduled jobs are listed
  3. Check last run times and results are populated
  **Expected:** All jobs visible with schedule, status, last run
  **If not:** Note which jobs are missing or showing incorrect data

## Verification

curl -sf http://localhost:3000/cron | grep -q "Scheduled Jobs"
python3 -c "import importlib.util; spec=importlib.util.spec_from_file_location('cron', 'web/blueprints/cron.py'); assert spec is not None; print('OK: blueprint exists')"
grep -q "cron" web/blueprints/__init__.py

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

### 2026-03-12T06:13:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-447-cron-registry-page-in-watchtower-read-on.md
- **Context:** Initial task creation
