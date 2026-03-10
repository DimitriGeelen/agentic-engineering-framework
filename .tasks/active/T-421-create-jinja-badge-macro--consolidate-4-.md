---
id: T-421
name: "Create Jinja badge macro — consolidate 4+ badge implementations (H2)"
description: >
  Create _partials/badge.html Jinja macro to replace 4+ separate badge implementations across gaps.html, risks.html, decisions.html, assumptions.html. Each duplicates color scheme, padding, border-radius. Same mark element with inline styles repeated with slightly inconsistent values. Directive score: H2=7. Ref: docs/reports/T-411-refactoring-directive-scoring.md

status: captured
workflow_type: refactor
owner: agent
horizon: now
tags: [refactoring, html, watchtower, usability]
components: [web/templates/_partials/badge.html, web/templates/gaps.html, web/templates/risks.html, web/templates/assumptions.html]
related_tasks: [T-411]
created: 2026-03-10T21:03:21Z
last_update: 2026-03-10T21:03:21Z
date_finished: null
---

# T-421: Create Jinja badge macro — consolidate 4+ badge implementations (H2)

## Context

Refactoring finding H2 (score 7) from `docs/reports/T-411-refactoring-directive-scoring.md`.

**H2 — Reusable status badge component:**
Status badges with inline styles replicated in 4+ templates: gaps.html:15-35, risks.html:26-35,
decisions.html:23-27, assumptions.html:173-179. Each has its own mark element with hardcoded
background-color, color, padding, border-radius, font-size.
See research artifact § "HTML TEMPLATES" row H2.

## Acceptance Criteria

### Agent
- [ ] _partials/badge.html Jinja macro created
- [ ] Macro accepts status/severity and outputs consistent badge
- [ ] At least 4 templates converted to use the macro
- [ ] Badge colors consistent across all pages

### Human
- [ ] [RUBBER-STAMP] Badges look consistent across pages
  **Steps:**
  1. Open http://localhost:3000/risks
  2. Open http://localhost:3000/assumptions
  3. Compare badge styling (colors, sizing, padding)
  **Expected:** Badges look identical in style across pages
  **If not:** Note which page has different badge styling

## Verification

test -f web/templates/_partials/badge.html
grep -q 'badge' web/templates/gaps.html
grep -q 'import.*badge' web/templates/risks.html || grep -q 'badge' web/templates/risks.html

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

### 2026-03-10T21:03:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-421-create-jinja-badge-macro--consolidate-4-.md
- **Context:** Initial task creation
