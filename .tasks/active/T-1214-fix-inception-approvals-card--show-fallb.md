---
id: T-1214
name: "Fix inception approvals card — show fallback context when recommendation missing (T-1213 GO)"
description: >
  Fix inception approvals card — show fallback context when recommendation missing (T-1213 GO)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-13T09:18:31Z
last_update: 2026-04-13T09:18:31Z
date_finished: null
---

# T-1214: Fix inception approvals card — show fallback context when recommendation missing (T-1213 GO)

## Context

T-1213 GO. RC-1: template hides recommendation block entirely when data is missing. Fix: add fallback
context block showing Go/No-Go Criteria and warning when recommendation is absent. Also pass Go/No-Go
Criteria from backend and make problem statement more prominent.

## Acceptance Criteria

### Agent
- [x] Template shows fallback context when `t.recommendation` is empty
- [x] Backend passes `go_nogo_criteria` field to template for fallback display
- [x] Warning banner shown when recommendation is missing
- [x] Approvals page loads without errors (HTTP 200)

### Human
- [ ] [REVIEW] Inception cards on /approvals show useful context for decision-making
  **Steps:**
  1. Open http://192.168.10.107:3001/approvals in browser
  2. Look at inception decision cards
  3. Verify recommendation OR fallback context is visible
  **Expected:** Every card shows either agent recommendation or Go/No-Go Criteria with warning
  **If not:** Note which card is bare and what's missing

## Verification

curl -sf -o /dev/null -w "%{http_code}" http://localhost:3001/approvals | grep -q 200

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

### 2026-04-13T09:18:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1214-fix-inception-approvals-card--show-fallb.md
- **Context:** Initial task creation
