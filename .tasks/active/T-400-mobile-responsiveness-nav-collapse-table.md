---
id: T-400
name: "Mobile responsiveness: nav collapse, table scroll, form stacking"
description: >
  Fix mobile breakpoints below 576px. P1: nav doesn't collapse on mobile. P2: 3-col form layout doesn't stack. P3: tables overflow viewport. Pico CSS handles tablets (768px) but phone (<576px) breaks nav, forms, and tables.

status: work-completed
workflow_type: build
owner: human
horizon: next
tags: []
components: [web/templates/base.html]
related_tasks: []
created: 2026-03-10T09:44:22Z
last_update: 2026-03-10T22:04:14Z
date_finished: 2026-03-10T10:37:37Z
---

# T-400: Mobile responsiveness: nav collapse, table scroll, form stacking

## Context

Added mobile responsiveness to `base.html`: hamburger nav toggle at <768px, table-responsive auto-wrapping via JS, form stacking at <576px, 3-col grid collapse. All changes in one file (base.html) for global effect.

## Acceptance Criteria

### Agent
- [x] Hamburger button appears at <768px, hidden at desktop
- [x] Nav items toggle open/close on hamburger click
- [x] Nav items auto-close on link click (mobile)
- [x] Tables wrapped in `.table-responsive` for horizontal scroll
- [x] 3-col grids collapse to 1-col at <768px (risks stats, fabric overview)
- [x] `.grid` and `.form-row` stack to 1-col at <576px (settings form)
- [x] Ambient strip trims less important items on phone
- [x] Dashboard renders at 375px width without horizontal overflow

### Human
- [ ] [REVIEW] Mobile layout looks good on phone
  **Steps:**
  1. Open http://localhost:3000 on a phone or use browser dev tools at 375px
  2. Tap hamburger — nav should expand with Work/Knowledge/Architecture/Govern/Docs/Search
  3. Tap a nav link — nav should collapse and page loads
  4. Check /risks — stats cards should stack, controls table should scroll horizontally
  5. Check /settings — form fields should stack vertically
  **Expected:** All pages readable, no horizontal overflow, nav works
  **If not:** Note which page/element overflows or doesn't stack

## Verification

# Dashboard renders at mobile width
curl -sf http://localhost:3000/
# Nav toggle button exists
curl -sf http://localhost:3000/ | grep -q 'nav-toggle'
# Table-responsive JS exists
curl -sf http://localhost:3000/ | grep -q 'table-responsive'
# Mobile media query exists
curl -sf http://localhost:3000/ | grep -q 'max-width: 768px'
# Settings page renders
curl -sf http://localhost:3000/settings/
# Risks page renders
curl -sf http://localhost:3000/risks

## Decisions

None — standard responsive patterns applied.

## Updates

### 2026-03-10T09:44:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-400-mobile-responsiveness-nav-collapse-table.md
- **Context:** Initial task creation

### 2026-03-10T10:32:48Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-10T10:37:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-10T22:04:14Z — status-update [task-update-agent]
- **Change:** horizon: now → next
