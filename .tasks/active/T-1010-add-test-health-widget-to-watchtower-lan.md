---
id: T-1010
name: "Add test health widget to Watchtower landing page — show test counts from /health"
description: >
  Add test health widget to Watchtower landing page — show test counts from /health

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-07T10:17:31Z
last_update: 2026-04-07T10:21:44Z
date_finished: null
---

# T-1010: Add test health widget to Watchtower landing page — show test counts from /health

## Context

Add test infrastructure counts to the System Health section of the Watchtower landing page. Data comes from /health endpoint (T-1008).

## Acceptance Criteria

### Agent
- [x] Landing page System Health section shows test file counts
- [x] Test counts display correctly (Playwright, unit, integration, web)
- [x] Playwright test verifies test counts appear on landing page
- [x] /health endpoint Ollama check has 3s timeout (prevents test infrastructure from hanging)
- [x] conftest.py handles 503 health response (Ollama unreachable but app healthy)

## Verification

cd /opt/999-Agentic-Engineering-Framework && curl -sf http://localhost:3000/ -o /tmp/wt-landing.html && grep -q "playwright" /tmp/wt-landing.html

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

### 2026-04-07T10:17:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1010-add-test-health-widget-to-watchtower-lan.md
- **Context:** Initial task creation
