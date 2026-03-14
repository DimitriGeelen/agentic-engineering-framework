---
id: T-398
name: "Dashboard health summary: concerns, quality scores, focus task, stale warnings"
description: >
  Dashboard health summary: concerns, quality scores, focus task, stale warnings

status: work-completed
workflow_type: build
owner: human
horizon: next
tags: []
components: [web/blueprints/core.py, web/templates/cockpit.html, web/templates/index.html]
related_tasks: []
created: 2026-03-10T09:43:06Z
last_update: 2026-03-12T12:41:19Z
date_finished: 2026-03-10T10:32:28Z
---

# T-398: Dashboard health summary: concerns, quality scores, focus task, stale warnings

## Context

Enhanced both dashboard views (cockpit.html + index.html) with focus task bar, concerns register summary, and stale task warnings. Updated `core.py` with `_get_concerns_summary()`, `_get_focus_task()`, `_get_stale_tasks()` helpers.

## Acceptance Criteria

### Agent
- [x] Focus task bar shows current task ID + name with link to task detail
- [x] Concerns summary displays total watching, gaps, risks, high counts
- [x] `_get_attention_items()` reads concerns.yaml (with gaps.yaml fallback)
- [x] Both cockpit.html and index.html updated with new sections
- [x] Dashboard renders without errors (`curl -sf http://localhost:3000/`)
- [x] Concerns numbers match actual concerns.yaml data (11 watching, 7 gaps, 4 risks, 2 high)

### Human
- [x] [RUBBER-STAMP] Dashboard looks good in browser
  **Steps:**
  1. Open http://localhost:3000 in browser
  2. Check Focus task bar appears at top with blue left border
  3. Check System Health shows Concerns/Gaps/Risks/High numbers
  4. Click "Concerns →" link — should navigate to /risks page
  **Expected:** All elements visible, numbers match, links work
  **If not:** Note which element is missing or misaligned

## Verification

# Dashboard renders
curl -sf http://localhost:3000/
# Focus task appears in output
curl -sf http://localhost:3000/ | grep -q 'T-398'
# Concerns summary renders
curl -sf http://localhost:3000/ | grep -q 'Concerns'
# Python imports work (no syntax errors in core.py)
python3 -c "from web.blueprints.core import _get_concerns_summary; print(_get_concerns_summary())"

## Decisions

None — straightforward enhancement with no meaningful alternatives.

## Updates

### 2026-03-10T09:43:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-398-dashboard-health-summary-concerns-qualit.md
- **Context:** Initial task creation

### 2026-03-10T10:32:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-10T22:04:14Z — status-update [task-update-agent]
- **Change:** horizon: now → next
