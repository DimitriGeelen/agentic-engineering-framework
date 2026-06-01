---
id: T-826
name: "Timeline token usage — add per-session token costs to /timeline cards"
description: >
  Timeline token usage — add per-session token costs to /timeline cards

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: [web/blueprints/timeline.py, web/templates/timeline.html]
related_tasks: []
created: 2026-04-03T23:38:50Z
last_update: 2026-04-03T23:41:12Z
date_finished: 2026-04-03T23:41:12Z
---

# T-826: Timeline token usage — add per-session token costs to /timeline cards

## Context

Build task from T-825 GO decision. Add `token_usage` from handover frontmatter to /timeline session cards. See `docs/reports/T-825-timeline-token-usage.md`.

## Acceptance Criteria

### Agent
- [x] timeline.py extracts `token_usage` from handover frontmatter
- [x] timeline.html displays token_usage badge on session cards
- [x] Emergency-collapsed sessions excluded from token display
- [x] /timeline page loads without errors
- [x] Token usage badges appear on timeline session cards (reclassified from Human RUBBER-STAMP per T-954)

### Human

## Verification

# Verify token_usage field is extracted in timeline.py
grep -q "token_usage" web/blueprints/timeline.py
# Verify badge markup exists in template
grep -q "token_usage" web/templates/timeline.html
curl -sf http://localhost:3000/timeline | grep -q "token\|Token"

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

### 2026-04-03T23:38:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-826-timeline-token-usage--add-per-session-to.md
- **Context:** Initial task creation

### 2026-04-03T23:41:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
