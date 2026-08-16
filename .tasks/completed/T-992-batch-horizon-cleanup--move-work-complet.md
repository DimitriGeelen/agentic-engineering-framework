---
id: T-992
name: "Batch horizon cleanup — move work-completed now tasks to next"
description: >
  Batch horizon cleanup — move work-completed now tasks to next

status: work-completed
workflow_type: refactor
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-07T09:51:49Z
last_update: '2026-08-16T22:25:45Z'
date_finished: 2026-04-13T06:12:09Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:34Z'
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
  - ts: '2026-08-16T22:25:45Z'
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

# T-992: Batch horizon cleanup — move work-completed now tasks to next

## Context

Tasks with `work-completed` status and `horizon: now` are cluttering the immediate work queue. They only need human review, not agent work. Moving to `horizon: next` keeps "now" clean for actionable items.

## Acceptance Criteria

### Agent
- [x] All work-completed + horizon:now tasks moved to horizon:next
- [x] No tasks that genuinely need agent work are affected
- [x] fw doctor shows reduced stale task count

## Verification

# Verify no work-completed tasks have horizon:now in frontmatter (excluding T-992 itself)
cd /opt/999-Agentic-Engineering-Framework && test $(for f in $(grep -l 'status: work-completed' .tasks/active/T-*.md 2>/dev/null | grep -v T-992); do sed -n '/^---$/,/^---$/p' "$f" | grep -q '^horizon: now$' && echo "$f"; done | wc -l) -eq 0

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

### 2026-04-07T09:51:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-992-batch-horizon-cleanup--move-work-complet.md
- **Context:** Initial task creation

### 2026-04-07T09:52:28Z — status-update [task-update-agent]
- **Change:** status: started-work → issues
- **Reason:** User vetoed batch horizon move

### 2026-04-12T09:26:31Z — status-update [task-update-agent]
- **Change:** horizon: now → next

### 2026-04-12T09:26:43Z — status-update [task-update-agent]
- **Change:** status: issues → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-12T09:26:43Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-04-13T06:11:06Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-13T06:12:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-38f73d45
- **Timestamp:** 2026-06-02T15:06:06Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `cd /opt/999-Agentic-Engineering-Framework && test $(for f in $(grep -l 'status: work-completed' .tasks/active/T-*.md 2>/dev/null | grep -v T-992); do sed -n '/^---$/,/^---$/p' "$f" | grep -q '^horizon`
