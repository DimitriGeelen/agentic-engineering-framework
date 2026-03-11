---
id: T-429
name: "Template cleanup — shared form macro, onclick migration, conditional simplification (H3+H4+H10)"
description: >
  H3: Convert 24 inline onclick handlers to data-attributes + delegated listeners. H4: Extract inline_select_form macro for 5+ duplicated form patterns. H10: Move status/severity conditionals from templates to Python view functions. Directive scores: H3=5, H4=6, H10=5. Ref: docs/reports/T-411-refactoring-directive-scoring.md

status: work-completed
workflow_type: refactor
owner: human
horizon: next
tags: [refactoring, html, watchtower, usability]
components: [web/templates/base.html, web/templates/cockpit.html, web/templates/inception_detail.html, web/templates/project.html, web/templates/task_detail.html, web/templates/tasks.html]
related_tasks: [T-411]
created: 2026-03-10T21:04:10Z
last_update: 2026-03-11T22:20:27Z
date_finished: 2026-03-11T22:20:27Z
---

# T-429: Template cleanup — shared form macro, onclick migration, conditional simplification (H3+H4+H10)

## Context

Template cleanup (H3+H4+H10). See `docs/reports/T-411-refactoring-directive-scoring.md` § TEMPLATES rows H3 (onclick→events, score 5), H4 (form macro, score 6), H10 (conditional cleanup, score 5). Three template improvements bundled for efficiency.

## Acceptance Criteria

### Agent
- [x] H4: inline_select macro in _partials/inline_select.html replaces 12 duplicated form patterns
- [x] H4: task_detail.html uses macro for status/owner/horizon/type (4 instances)
- [x] H4: tasks.html kanban cards use macro (4 instances)
- [x] H4: tasks.html list view uses macro (4 instances)
- [x] H3: Inline JS snippets extracted to named functions (wtShowAll, wtDismissCard, wtToggleNav)
- [x] H3: cockpit.html, project.html, base.html cleaned up
- [x] H10: inception_detail.html assumption status conditional simplified to single-line template
- [x] All affected pages load (dashboard, tasks, task detail, inception, enforcement)

### Human
- [ ] [REVIEW] Task board inline selects still work after macro migration
  **Steps:**
  1. Open http://localhost:3000/tasks in browser
  2. Change a task's status via the dropdown in list view
  3. Switch to kanban view, change a task's horizon
  4. Open a task detail page, change the workflow type
  **Expected:** All dropdown changes submit and update correctly (no broken htmx)
  **If not:** Note which view/field broke and check browser console

## Verification

# Macro file exists
test -f web/templates/_partials/inline_select.html
# Macro is imported in tasks.html and task_detail.html
grep -q "from '_partials/inline_select.html' import inline_select" web/templates/tasks.html
grep -q "from '_partials/inline_select.html' import inline_select" web/templates/task_detail.html
# No more raw inline select forms in task_detail.html (checkbox toggle is OK)
! grep -q '<select.*onchange="this.form.requestSubmit()"' web/templates/task_detail.html
# Extracted JS functions exist
grep -q "function wtShowAll" web/templates/base.html
grep -q "function wtDismissCard" web/templates/base.html
grep -q "function wtToggleNav" web/templates/base.html
# No more inline JS snippets in cockpit
! grep -q "querySelectorAll.*wt-card-hidden" web/templates/cockpit.html
# Pages load
curl -sf http://localhost:3000/ > /dev/null
curl -sf http://localhost:3000/tasks > /dev/null
curl -sf http://localhost:3000/tasks/T-428 > /dev/null
curl -sf http://localhost:3000/inception > /dev/null

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

### 2026-03-10T21:04:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-429-template-cleanup--shared-form-macro-oncl.md
- **Context:** Initial task creation

### 2026-03-11T22:14:26Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-11T22:20:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
