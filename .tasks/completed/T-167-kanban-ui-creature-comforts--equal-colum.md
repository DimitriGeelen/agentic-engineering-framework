---
id: T-167
name: "Kanban UI creature comforts — equal columns, full-width, project label right,
  status refresh"
description: >
  Batch of 4 small UI tweaks: (1) Kanban columns equal 25% width, (2) Full-width layout
  using max screen space aligned with Watchtower header, (3) Move project name label
  to right side of ambient strip, (4) Auto-refresh board on status change with scroll
  to top not bottom

status: work-completed
workflow_type: build
owner: claude-code
horizon:
tags: []
related_tasks: []
created: 2026-02-18T16:11:42Z
last_update: '2026-08-16T22:24:40Z'
date_finished: 2026-02-18T17:20:55Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:55Z'
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
  - ts: '2026-08-16T22:24:40Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-167: Kanban UI creature comforts — equal columns, full-width, project label right, status refresh

## Context

Batch of 4 kanban UI tweaks to improve screen real estate at 1920x1080.

## Acceptance Criteria

- [x] Kanban columns equal 25% width (minmax(0, 1fr))
- [x] Full-width layout overriding Pico container max-width
- [x] Project name label moved to right side of ambient strip
- [x] Auto-refresh board on status change with scroll to top
- [x] Compact cards (reduced padding, ellipsis truncation)
- [x] Completed column capped at 10 with "+N more" link
- [x] Compact page header (title + count + toggle inline)

## Verification

curl -sf http://localhost:3000/tasks?view=board | grep -q "tasks-page-header"
curl -sf http://localhost:3000/tasks?view=board | grep -q "minmax(0, 1fr)"
curl -sf http://localhost:3000/tasks?view=board | grep -q "scrollTo(0, 0)"
curl -sf http://localhost:3000/tasks?view=board | grep -q "+152 more"

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

### 2026-02-18T16:11:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-167-kanban-ui-creature-comforts--equal-colum.md
- **Context:** Initial task creation

### 2026-02-18T16:57:17Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-18T17:20:55Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-611999b1
- **Timestamp:** 2026-06-02T14:59:05Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 4

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `curl -sf http://localhost:3000/tasks?view=board | grep -q "tasks-page-header"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `curl -sf http://localhost:3000/tasks?view=board | grep -q "minmax(0, 1fr)"`
  3. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `curl -sf http://localhost:3000/tasks?view=board | grep -q "scrollTo(0, 0)"`
  4. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `curl -sf http://localhost:3000/tasks?view=board | grep -q "+152 more"`
