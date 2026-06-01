---
id: T-827
name: "Timeline per-session token delta — show session-specific token and turn counts alongside cumulative"
description: >
  Timeline per-session token delta — show session-specific token and turn counts alongside cumulative

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: [web/blueprints/timeline.py, web/templates/timeline.html]
related_tasks: []
created: 2026-04-03T23:43:16Z
last_update: 2026-04-03T23:45:37Z
date_finished: 2026-04-03T23:45:37Z
---

# T-827: Timeline per-session token delta — show session-specific token and turn counts alongside cumulative

## Context

Refinement of T-826. The `token_usage` field shows cumulative totals — add per-session deltas by subtracting consecutive session values.

## Acceptance Criteria

### Agent
- [x] timeline.py parses `token_usage` string into numeric values
- [x] Per-session delta calculated by subtracting previous session's cumulative
- [x] Template shows both per-session delta and cumulative total
- [x] /timeline page loads without errors
- [x] Per-session token deltas display correctly on timeline (reclassified from Human RUBBER-STAMP per T-954)

### Human

## Verification

grep -q "session_tokens" web/blueprints/timeline.py
grep -q "session_tokens" web/templates/timeline.html
curl -sf http://localhost:3000/timeline | grep -q "session"

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

### 2026-04-03T23:43:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-827-timeline-per-session-token-delta--show-s.md
- **Context:** Initial task creation

### 2026-04-03T23:45:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
