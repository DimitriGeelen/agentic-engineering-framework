---
id: T-443
name: "Build OneDev PR-to-task cron job (local-only)"
description: >
  Build OneDev PR-to-task cron job (local-only)

status: work-completed
workflow_type: build
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-03-11T23:56:54Z
last_update: '2026-06-11T22:24:21Z'
date_finished: 2026-03-11T23:59:52Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:21Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-443: Build OneDev PR-to-task cron job (local-only)

## Context

Inception T-442 approved GO. See `docs/reports/T-442-onedev-pr-to-task-cron.md` for research.

## Acceptance Criteria

### Agent
- [x] Script `deploy/onedev-pr-sync.sh` polls OneDev API for open PRs
- [x] Creates framework tasks (horizon: next, owner: human, tags: onedev,pr)
- [x] Tracks seen PRs in `.context/working/.onedev-pr-seen` — idempotent
- [x] Script and seen file listed in `.gitignore` (local-only)
- [x] Cron job installed at `/etc/cron.d/agentic-onedev-sync` (every 15 min)
- [x] Dry-run mode (`--dry-run`) works
- [x] Fixed `find_task_file` regression in `fw inception decide` (bin/fw missing `source tasks.sh`)

### Human
- [x] [RUBBER-STAMP] Verify PR #3 task (T-444) appears on task board
  **Steps:**
  1. Open http://localhost:3000/tasks
  2. Look for "PR #3: L-077/L-078/L-079..."
  **Expected:** Task visible with tags `onedev`, `pr` and horizon `next`
  **If not:** Check `.tasks/active/T-444-*` exists

## Verification

test -x deploy/onedev-pr-sync.sh
test -f /etc/cron.d/agentic-onedev-sync
python3 -c "assert 'deploy/onedev-pr-sync.sh' in open('.gitignore').read(); print('OK')"
python3 -c "assert '.onedev-pr-seen' in open('.gitignore').read(); print('OK')"
test -f .context/working/.onedev-pr-seen
grep -q "3: T-444" .context/working/.onedev-pr-seen

## Decisions

### 2026-03-12 — Local-only approach
- **Chose:** Script in deploy/ + .gitignore, separate cron file
- **Why:** Nothing propagates to GitHub; clean separation from framework core
- **Rejected:** fw subcommand (would be in git), adding to existing cron file (mixes concerns)

## Updates

### 2026-03-11T23:56:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-443-build-onedev-pr-to-task-cron-job-local-o.md
- **Context:** Initial task creation

### 2026-03-11T23:59:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b6b7cbf2
- **Timestamp:** 2026-06-02T15:02:52Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
