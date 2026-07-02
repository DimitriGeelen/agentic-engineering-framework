---
id: T-658
name: "Fix cron audit retention — use filename date parsing instead of mtime"
description: >
  Fix cron audit retention — use filename date parsing instead of mtime

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [bin/fw]
related_tasks: []
created: 2026-03-28T16:05:19Z
last_update: '2026-06-11T22:24:26Z'
date_finished: 2026-03-28T16:09:06Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:26Z'
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

# T-658: Fix cron audit retention — use filename date parsing instead of mtime

## Context

Cron audit retention uses `find -mtime +7 -delete` but file mtimes get reset by git operations (checkout, merge, etc.), so files from 24 days ago have mtime of 6 days. Retention never fires. Fix: parse the date from filenames (format: `YYYY-MM-DD-HHMM.yaml`) instead of relying on filesystem mtime. Affects cron-registry.yaml, /etc/cron.d/ installed crontab, and `fw cron generate`.

## Acceptance Criteria

### Agent
- [x] Retention command in cron-registry.yaml uses filename-based date parsing
- [x] `fw cron generate` produces updated retention command in crontab
- [x] Stale files (>7 days by filename) cleaned up (669 files removed)
- [x] LATEST-CRON.yaml preserved (not deleted by retention)

## Verification

# Registry has updated retention command (not -mtime)
grep -q 'cutoff' .context/cron-registry.yaml
# No stale files remain
python3 -c "import os,datetime; cutoff=str(datetime.date.today()-datetime.timedelta(days=7)); old=[f for f in os.listdir('.context/audits/cron') if f.endswith('.yaml') and len(f)>=15 and f[4]=='-' and f[:10]<cutoff]; assert len(old)==0, f'{len(old)} stale'"

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

### 2026-03-28T16:05:19Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-658-fix-cron-audit-retention--use-filename-d.md
- **Context:** Initial task creation

### 2026-03-28T16:09:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7e85618c
- **Timestamp:** 2026-06-02T15:04:10Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
