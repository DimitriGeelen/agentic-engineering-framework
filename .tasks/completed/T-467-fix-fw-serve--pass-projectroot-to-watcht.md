---
id: T-467
name: "Fix fw serve — pass PROJECT_ROOT to Watchtower"
description: >
  Bilderkarte analysis finding: running 'fw serve' inside a consumer project still
  serves the framework dashboard because bin/fw routes serve directly without passing
  PROJECT_ROOT. Fix: detect PROJECT_ROOT in bin/fw serve handler and inject it as
  env var. Fallback to FRAMEWORK_ROOT if no project found. Ref: /tmp/fw-agent-onboarding-gaps.md
  section 3.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [watchtower, multi-project]
components: []
related_tasks: []
created: 2026-03-12T18:34:28Z
last_update: '2026-06-11T22:24:22Z'
date_finished: 2026-03-12T21:00:48Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:22Z'
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

# T-467: Fix fw serve — pass PROJECT_ROOT to Watchtower

## Context

`watchtower.sh` does `cd $FRAMEWORK_ROOT` then starts Flask without passing PROJECT_ROOT. Flask app reads `PROJECT_ROOT` env var (web/shared.py:21) but it's never set in the serve path.

## Acceptance Criteria

### Agent
- [x] watchtower.sh passes PROJECT_ROOT env var when starting Flask
- [x] Falls back to FRAMEWORK_ROOT if PROJECT_ROOT not set

## Verification

grep -q "PROJECT_ROOT" bin/watchtower.sh

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

### 2026-03-12T18:34:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-467-fix-fw-serve--pass-projectroot-to-watcht.md
- **Context:** Initial task creation

### 2026-03-12T20:59:49Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-12T21:00:48Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3351e7a1
- **Timestamp:** 2026-06-02T15:03:00Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
