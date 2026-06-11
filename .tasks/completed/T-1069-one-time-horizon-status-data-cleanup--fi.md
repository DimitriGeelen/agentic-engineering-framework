---
id: T-1069
name: "One-time horizon-status data cleanup — fix 52 inconsistent tasks"
description: >
  Move 24 stuck work-completed tasks to completed/. Fix 28 started-work tasks with
  wrong horizon (demote to captured). Origin: T-1067 GO.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-08T10:32:46Z
last_update: '2026-06-11T22:23:39Z'
date_finished: 2026-04-08T10:39:19Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:39Z'
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

# T-1069: One-time horizon-status data cleanup — fix 52 inconsistent tasks

## Context

Origin: T-1067 GO. Fix existing data to match new invariants from T-1068.

## Acceptance Criteria

### Agent
- [x] 28 started-work + horizon:next/later tasks demoted to captured
- [x] 24 stuck work-completed tasks (all ACs checked) moved to completed/
- [x] No started-work tasks with horizon != now remain (0 violations)
- [x] No work-completed tasks with all ACs checked remain in active/ (77 remaining are legitimate partial-completes)

## Verification

# No started-work tasks with wrong horizon
test $(for f in .tasks/active/T-*.md; do s=$(grep '^status:' "$f" | head -1 | sed 's/status: *//'); h=$(grep '^horizon:' "$f" | head -1 | sed 's/horizon: *//'); [ "$s" = "started-work" ] && [ "$h" != "now" ] && echo bad; done | wc -l) -eq 0

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

### 2026-04-08T10:32:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1069-one-time-horizon-status-data-cleanup--fi.md
- **Context:** Initial task creation

### 2026-04-08T10:38:05Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-08T10:39:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b46c856e
- **Timestamp:** 2026-06-02T14:54:56Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
