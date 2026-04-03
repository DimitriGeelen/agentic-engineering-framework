---
id: T-829
name: "Input/output token breakdown — enrich handover frontmatter and timeline display"
description: >
  Input/output token breakdown — enrich handover frontmatter and timeline display

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-03T23:53:55Z
last_update: 2026-04-03T23:53:55Z
date_finished: null
---

# T-829: Input/output token breakdown — enrich handover frontmatter and timeline display

## Context

Build task from T-828 GO decision. Add input/cache_read/cache_create/output token counts to handover frontmatter and display breakdown in /timeline. See `docs/reports/T-828-token-breakdown-inception.md`.

## Acceptance Criteria

### Agent
- [x] handover.sh extracts input/cache_read/cache_create/output from costs_main current
- [x] Handover frontmatter includes 4 new numeric token fields
- [x] timeline.py reads breakdown fields and passes to template
- [x] timeline.html shows token breakdown (tooltip on badge + detail panel when expanded)
- [x] Graceful fallback for old handovers without breakdown fields

### Human
- [ ] [RUBBER-STAMP] Token breakdown visible on timeline session cards
  **Steps:**
  1. Open http://192.168.10.107:3000/timeline in browser
  2. Hover or inspect a recent session card for token breakdown
  3. Verify input/cache/output categories are shown
  **Expected:** Breakdown visible with meaningful numbers per category
  **If not:** Note which cards or categories are missing

## Verification

grep -q "token_input" agents/handover/handover.sh
grep -q "token_input" web/blueprints/timeline.py

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

### 2026-04-03T23:53:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-829-inputoutput-token-breakdown--enrich-hand.md
- **Context:** Initial task creation
