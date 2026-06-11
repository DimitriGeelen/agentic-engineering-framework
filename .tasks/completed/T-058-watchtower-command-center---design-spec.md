---
id: T-058
name: Watchtower Command Center - Design Spec
description: >
  Design specification for transforming the web UI from read-only artifact browser
  into Watchtower Command Center. Covers 8 lifecycle stages, 4 implementation phases,
  nav redesign, dashboard reimagining, write actions, and progressive disclosure.
status: work-completed
workflow_type: specification
owner: human
created: 2026-02-14T18:05:02Z
last_update: '2026-06-11T22:23:36Z'
date_finished: 2026-02-15T08:12:45Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:36Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 3
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=3 (body:fw-recall-or-memory-link); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
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


### 2026-02-14T22:17:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-02-15T08:12:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cf42d440
- **Timestamp:** 2026-06-02T14:54:18Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
