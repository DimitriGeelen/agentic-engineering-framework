---
id: T-1191
name: "Fix T-603: add /etc/cron.d/ to project boundary safe zones for cron install"
description: >
  Fix T-603: add /etc/cron.d/ to project boundary safe zones for cron install

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-12T22:02:26Z
last_update: '2026-06-11T22:23:42Z'
date_finished: 2026-04-12T22:03:47Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:42Z'
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

# T-1191: Fix T-603: add /etc/cron.d/ to project boundary safe zones for cron install

## Context

T-603 inception (GO): The project boundary hook blocks writes to `/etc/cron.d/` which is needed by `fw cron install`. Fix: add `/etc/cron.d/` to the safe zone list in the Python analysis (Pattern 3).

## Acceptance Criteria

### Agent
- [x] `check-project-boundary.sh` allows writes to `/etc/cron.d/` paths
- [x] Vendored copy synced
- [x] Header comment updated with new safe zone

## Verification

grep -q "etc/cron" agents/context/check-project-boundary.sh

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

### 2026-04-12T22:02:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1191-fix-t-603-add-etccrond-to-project-bounda.md
- **Context:** Initial task creation

### 2026-04-12T22:03:47Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d1425200
- **Timestamp:** 2026-06-02T14:55:48Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — `check-project-boundary.sh` allows writes to `/etc/cron.d/` paths
  - **AC-verify-mismatch** (narrow, heuristic) — `path=etc/cron.d in: `check-project-boundary.sh` allows writes to `/etc/cron.d/` paths`
