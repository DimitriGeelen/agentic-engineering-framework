---
id: T-1241
name: "Fix Watchtower /cron page — last 5 files too narrow, infrequent jobs always show no data"
description: >
  Fix Watchtower /cron page — last 5 files too narrow, infrequent jobs always show no data

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-13T19:50:36Z
last_update: 2026-04-25T14:09:28Z
date_finished: 2026-04-13T20:12:06Z
---

# T-1241: Fix Watchtower /cron page — last 5 files too narrow, infrequent jobs always show no data

## Context

`_last_run_info()` in `web/blueprints/cron.py` only reads last 5 cron output files.
With jobs running every 15-30 min, 5 files cover ~2.5 hours. Daily/weekly/6h jobs never appear.
Also: non-audit jobs (docs, retention, pickup) have no `--section` flag so matching fails entirely.

## Acceptance Criteria

### Agent
- [x] `_last_run_info()` scans enough files to find the most recent output for each unique section key
- [x] Non-audit jobs (docs, retention, pickup) show last-run info when available
- [x] /cron page shows data for all jobs that have executed at least once (10/11, only oe-weekly pending Monday)
- [x] Web tests pass (142/142)
- [x] Pickup processor interval changed from 15min to 30s (sleep trick)

<!-- T-1462: rubber-stamp converted — verification command checks the same condition mechanically.
     Note: registry has grown from 11 → 16 jobs since T-1241 was filed; 2 weekly + 1 paused
     legitimately show "no data". Threshold raised from ≤2 to ≤3. -->

## Verification

curl -sf "$(bin/fw watchtower url)/cron" | python3 -c "import sys, re; html=sys.stdin.read(); count=len(re.findall(r'no data', html)); print(f'no_data={count}'); exit(0 if count <= 3 else 1)"

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

### 2026-04-13T19:50:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1241-fix-watchtower-cron-page--last-5-files-t.md
- **Context:** Initial task creation

### 2026-04-13T20:12:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
