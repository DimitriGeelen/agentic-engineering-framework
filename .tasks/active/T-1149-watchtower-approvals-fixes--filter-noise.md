---
id: T-1149
name: "Watchtower approvals fixes — filter noise, restart server"
description: >
  Watchtower approvals fixes — filter noise, restart server

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-12T10:56:28Z
last_update: 2026-04-12T10:56:28Z
date_finished: null
---

# T-1149: Watchtower approvals fixes — filter noise, restart server

## Context

Approvals page shows 31 captured inception tasks without recommendations — noise that dilutes the 12 real pending decisions. Filter: only show inceptions with `## Recommendation` content (T-1123 fix).

## Acceptance Criteria

### Agent
- [x] Approvals page filters out inception tasks without recommendations
- [x] Watchtower restarted with fix

## Verification

bash -c 'curl -sf http://localhost:3000/approvals | grep -c "go-decision" | xargs test 20 -gt'
# The completion gate runs each command — if any exits non-zero, completion is blocked.

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

### 2026-04-12T10:56:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1149-watchtower-approvals-fixes--filter-noise.md
- **Context:** Initial task creation
