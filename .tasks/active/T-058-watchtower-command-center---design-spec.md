---
id: T-058
name: Watchtower Command Center - Design Spec
description: >
  Design specification for transforming the web UI from read-only artifact browser into Watchtower Command Center. Covers 8 lifecycle stages, 4 implementation phases, nav redesign, dashboard reimagining, write actions, and progressive disclosure.
status: started-work
workflow_type: specification
owner: human
created: 2026-02-14T18:05:02Z
last_update: 2026-02-14T21:30:00Z
date_finished: null
---

# T-058: Watchtower Command Center - Design Spec

## Context

[Link to design docs, specs, or predecessor tasks]

## Updates

### 2026-02-14T18:05:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-058-watchtower-command-center---design-spec.md
- **Context:** Initial task creation

### 2026-02-14T19:18:00Z — phase-1-implemented [claude-code]
- **Action:** Implemented Watchtower Phase 1 - Foundation
- **Output:** Transformed web UI into Watchtower command center
- **Changes:**
  - Renamed to Watchtower (titles, footer, nav brand)
  - Navigation redesign: 4 groups (Work | Knowledge | Govern) + Docs + Search
  - Dashboard: Needs Attention + Recent Activity + Project Pulse + audit badge
  - Inception detection + guided landing page with setup checklist
  - Ambient status strip (focus task, session age, audit status, attention count)
  - Quality Gate page (/quality) with Run Audit, Run Tests, Full Check
  - Traceability gauge and episodic completeness bars
  - 60 tests passing (up from 47)

### 2026-02-14T21:30:00Z — phase-2-implemented [claude-code]
- **Action:** Implemented Watchtower Phase 2 - Active Development
- **Output:** Added write actions and operational controls
- **Changes:**
  - Kanban board with 4-column status layout and click-to-advance cards
  - Board/list view toggle on tasks page
  - Create Task form (validates name, type, owner; shells out to fw task create)
  - Session cockpit blueprint (5 API routes: status, decision, learning, init, healing)
  - Session info widget (_session_strip.html) with git state and quick action forms
  - Decision/learning recording via fw context add-decision / add-learning
  - Healing diagnosis trigger via fw healing diagnose
  - 76 tests passing (up from 60)
