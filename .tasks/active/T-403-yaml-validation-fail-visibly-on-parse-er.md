---
id: T-403
name: "YAML validation: fail visibly on parse errors instead of silent skip (R-018, R-024)"
description: >
  Two watching risks: R-018 (invalid YAML disappears without error) and R-024 (UI silently drops data on parse errors). Add schema validation to watchtower data loading. Show error state in UI instead of empty sections. Same root cause — all _load_yaml() functions return {} on error.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-10T09:44:44Z
last_update: 2026-03-10T12:51:44Z
date_finished: null
---

# T-403: YAML validation: fail visibly on parse errors instead of silent skip (R-018, R-024)

## Context

R-018 and R-024 flagged that YAML parse errors were silently swallowed — 4 duplicate `_load_yaml()` functions across blueprints all returned `{}` on exception. Centralized into `web/shared.py:load_yaml()` with `logging.warning()` + per-request error collection. UI shows red banner on parse errors.

## Acceptance Criteria

### Agent
- [x] Centralized `load_yaml()` in `web/shared.py` with logging on parse errors
- [x] `core.py` uses shared `load_yaml` (local `_load_yaml` removed)
- [x] `metrics.py` uses shared `load_yaml` (local `_load_yaml` removed)
- [x] `risks.py` uses shared `load_yaml` (local `_load_yaml` removed)
- [x] `scanner.py` delegates to shared `load_yaml`
- [x] YAML parse errors logged via `logging.warning()`
- [x] Error banner in `base.html` shows parse errors to user
- [x] Clean data shows no error banner
- [x] Corrupted YAML shows red error banner with file/line/error details

### Human
- [ ] [RUBBER-STAMP] Pages load correctly in browser with no false error banners
  **Steps:**
  1. Open http://localhost:3000/ in browser
  2. Navigate to /risks, /metrics
  **Expected:** No red error banners on any page
  **If not:** Note which page shows false errors

## Verification

# Dashboard loads
curl -sf http://localhost:3000/
# Risks page loads
curl -sf http://localhost:3000/risks
# Metrics page loads
curl -sf http://localhost:3000/metrics
# shared.py parses
python3 -c "from web.shared import load_yaml; print('ok')"
# No false errors on clean data
python3 -c "import urllib.request; r=urllib.request.urlopen('http://localhost:3000/risks').read().decode(); assert 'YAML parse error' not in r"

## Decisions

None — straightforward consolidation of 4 duplicate functions into shared module.

## Updates

### 2026-03-10T09:44:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-403-yaml-validation-fail-visibly-on-parse-er.md
- **Context:** Initial task creation

### 2026-03-10T12:51:44Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
