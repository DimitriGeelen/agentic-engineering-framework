---
id: T-827
name: "Timeline per-session token delta — show session-specific token and turn counts alongside cumulative"
description: >
  Timeline per-session token delta — show session-specific token and turn counts alongside cumulative

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-03T23:43:16Z
last_update: 2026-04-03T23:43:16Z
date_finished: null
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

### Human
- [ ] [RUBBER-STAMP] Per-session token deltas display correctly on timeline
  **Steps:**
  1. Open http://192.168.10.107:3000/timeline in browser
  2. Verify each session card shows per-session tokens/turns (delta) alongside cumulative
  3. Spot-check: latest session should show a smaller delta than the cumulative total
  **Expected:** Two distinct numbers visible — session delta and cumulative
  **If not:** Note which sessions show incorrect or missing deltas

## Verification

grep -q "session_tokens" web/blueprints/timeline.py
grep -q "session_tokens" web/templates/timeline.html

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
