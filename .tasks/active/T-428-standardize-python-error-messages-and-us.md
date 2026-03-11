---
id: T-428
name: "Standardize Python error messages and user feedback (P11)"
description: >
  Error messages vary from detailed actionable text to one-liners without context. Define error classes (IndexNotReadyError, ModelUnavailableError) with message, severity, suggested_action. Use consistently across all endpoints. Directive score: P11=5. Ref: docs/reports/T-411-refactoring-directive-scoring.md

status: started-work
workflow_type: refactor
owner: agent
horizon: next
tags: [refactoring, python, watchtower, usability]
components: [web/blueprints/api.py, web/blueprints/discovery.py, web/ask.py, web/llm/ollama_provider.py, web/llm/openrouter_provider.py]
related_tasks: [T-411]
created: 2026-03-10T21:04:09Z
last_update: 2026-03-11T22:07:21Z
date_finished: null
---

# T-428: Standardize Python error messages and user feedback (P11)

## Context

Python error consistency (P11). See `docs/reports/T-411-refactoring-directive-scoring.md` § PYTHON row P11 (score 5). Define error classes with message, severity, suggested_action. Builds on T-417 (subprocess_utils) for consistent error patterns.

## Acceptance Criteria

### Agent
- [x] All "query too short" messages include "(min 2 characters)" — consistent across api.py and discovery.py
- [x] No raw `str(e)` exposed to users in api.py, discovery.py, or ask.py
- [x] Provider error messages (ollama, openrouter) sanitized to user-friendly text
- [x] api.py streaming endpoint uses sse_event() instead of raw f-string
- [x] All Python imports succeed
- [x] All web pages load (dashboard, search, tasks)

### Human
- [ ] [REVIEW] Error messages are user-friendly when LLM is unavailable
  **Steps:**
  1. Stop Ollama: `systemctl stop ollama` (or equivalent)
  2. Open http://localhost:3000/search, switch to Ask tab, ask a question
  3. Check the error message shown
  **Expected:** Friendly message like "No AI model available" not raw Python exception
  **If not:** Note the exact error text shown

## Verification

# All "query too short" consistent
grep -c "min 2 characters" web/blueprints/api.py | grep -q "3"
grep -c "min 2 characters" web/blueprints/discovery.py | grep -q "1"
# No raw str(e) in user-facing JSON responses
! grep -n 'jsonify.*str(e)' web/blueprints/api.py
! grep -n '"error": str(e)' web/blueprints/discovery.py
# api.py uses sse_event
! grep -n 'data:.*"type":.*"error"' web/blueprints/api.py
# Provider errors sanitized
grep -q "service unavailable" web/llm/ollama_provider.py
grep -q "service unavailable" web/llm/openrouter_provider.py
# Imports work
python3 -c "from web.shared import sse_event"
python3 -c "from web.blueprints.api import bp"
python3 -c "from web.blueprints.discovery import bp"
# Pages load
curl -sf http://localhost:3000/ > /dev/null
curl -sf http://localhost:3000/search > /dev/null

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

### 2026-03-10T21:04:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-428-standardize-python-error-messages-and-us.md
- **Context:** Initial task creation

### 2026-03-11T22:07:21Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
