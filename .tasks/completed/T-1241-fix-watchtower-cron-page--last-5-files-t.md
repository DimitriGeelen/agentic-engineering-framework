---
id: T-1241
name: "Fix Watchtower /cron page — last 5 files too narrow, infrequent jobs always
  show no data"
description: >
  Fix Watchtower /cron page — last 5 files too narrow, infrequent jobs always show
  no data

status: work-completed
workflow_type: build
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-04-13T19:50:36Z
last_update: '2026-06-11T22:23:43Z'
date_finished: 2026-04-13T20:12:06Z
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

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2cc3cd0d
- **Timestamp:** 2026-06-02T14:56:09Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
