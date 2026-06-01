---
id: T-639
name: "Unified /approvals page — Tier 0 + Human ACs + GO decisions in urgency-ordered sections"
description: >
  Unified /approvals page — Tier 0 + Human ACs + GO decisions in urgency-ordered sections

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-27T11:24:36Z
last_update: 2026-03-28T23:38:50Z
date_finished: 2026-03-27T11:32:06Z
---

# T-639: Unified /approvals page — Tier 0 + Human ACs + GO decisions in urgency-ordered sections

## Context

T-636 Phase 1, task 2. Extend Watchtower `/approvals` page to show three urgency-ordered sections: Tier 0 (agent blocked), pending GO decisions, and tasks with unchecked Human ACs. Design: docs/reports/fw-agent-t636-02-unified-page.md

## Acceptance Criteria

### Agent
- [x] /approvals page shows summary counts bar (Tier 0, GO decisions, Human ACs, total)
- [x] Section A: Tier 0 approvals displayed (existing cards preserved)
- [x] Section B: Pending inception GO/NO-GO decisions listed with task link and research artifacts
- [x] Section C: Tasks with unchecked Human ACs shown with interactive checkboxes
- [x] Empty state shown when nothing needs attention
- [x] Page loads without errors (curl returns 200)

### Human
- [x] [REVIEW] Unified approvals page shows all three sections correctly
  **Steps:**
  1. Open http://192.168.10.107:3000/approvals in browser
  2. Verify three sections visible: Tier 0, GO Decisions, Human ACs
  3. Check that Human AC checkboxes are interactive (toggle one)
  **Expected:** All sections render, checkboxes toggle via htmx
  **If not:** Note which section is broken and browser console errors

## Verification

curl -sf http://localhost:3000/approvals | grep -q 'Human Acceptance Criteria\|No pending'
python3 -c "from web.blueprints.approvals import _load_pending_human_acs, _load_pending_go_decisions"

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

### 2026-03-27T11:24:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-639-unified-approvals-page--tier-0--human-ac.md
- **Context:** Initial task creation

### 2026-03-27T11:32:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
