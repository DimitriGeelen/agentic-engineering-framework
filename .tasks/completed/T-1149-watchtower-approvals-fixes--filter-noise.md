---
id: T-1149
name: "Watchtower approvals fixes — filter noise, restart server"
description: >
  Watchtower approvals fixes — filter noise, restart server

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-12T10:56:28Z
last_update: 2026-04-12T10:57:52Z
date_finished: 2026-04-12T10:57:52Z
---

# T-1149: Watchtower approvals fixes — filter noise, restart server

## Context

Approvals page shows 31 captured inception tasks without recommendations — noise that dilutes the 12 real pending decisions. Filter: only show inceptions with `## Recommendation` content (T-1123 fix).

## Acceptance Criteria

### Agent
- [x] Approvals page filters out inception tasks without recommendations
- [x] Watchtower restarted with fix

## Verification

# Approvals page has fewer than 30 inception cards (was 77 before filter)
bash -c 'count=$(curl -sf http://localhost:3000/approvals | grep -c "approval-card go-decision"); test "$count" -lt 30'
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

### 2026-04-12T10:57:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
