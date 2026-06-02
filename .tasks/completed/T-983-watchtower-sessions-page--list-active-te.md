---
id: T-983
name: "Watchtower sessions page — list active terminal sessions with status and controls"
description: >
  Add /sessions page to Watchtower showing active terminal sessions from SessionRegistry. Shows session ID, provider, status, profile, created time. Kill button for active sessions.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [tests/playwright/test_sessions.py, web/blueprints/__init__.py, web/blueprints/sessions.py, web/templates/sessions.html]
related_tasks: []
created: 2026-04-06T23:21:13Z
last_update: 2026-04-06T23:23:39Z
date_finished: 2026-04-06T23:23:39Z
---

# T-983: Watchtower sessions page — list active terminal sessions with status and controls

## Context

T-967 added SessionRegistry with CRUD API at `/api/sessions`. This task adds a `/sessions` page to Watchtower that shows all sessions with their status, provider, and controls.

## Acceptance Criteria

### Agent
- [x] `web/blueprints/sessions.py` — blueprint with `/sessions` route
- [x] `web/templates/sessions.html` — template showing session list with provider, status, profile, created, kill button
- [x] Blueprint registered in `web/blueprints/__init__.py`
- [x] Page loads at `/sessions` with HTTP 200
- [x] Playwright test for /sessions page (4 tests in test_sessions.py)

## Verification

curl -sf http://localhost:3000/sessions | grep -q 'session'
grep -q 'sessions' web/blueprints/__init__.py

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

### 2026-04-06T23:21:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-983-watchtower-sessions-page--list-active-te.md
- **Context:** Initial task creation

### 2026-04-06T23:23:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-43ba33eb
- **Timestamp:** 2026-06-02T15:06:03Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#1 (Agent)** — `web/blueprints/sessions.py` — blueprint with `/sessions` route
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/sessions.py in: `web/blueprints/sessions.py` — blueprint with `/sessions` route`
- **AC#2 (Agent)** — `web/templates/sessions.html` — template showing session list with provider, status, profile, created, kill button
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/sessions.html in: `web/templates/sessions.html` — template showing session list with provider, status, profile, created, kill button`

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `curl -sf http://localhost:3000/sessions | grep -q 'session'`
