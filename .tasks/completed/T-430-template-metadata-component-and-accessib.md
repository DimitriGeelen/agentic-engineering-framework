---
id: T-430
name: "Template metadata component and accessibility improvements (H7+H11)"
description: >
  H7: Extract metadata table component for task/fabric/inception detail pages. H11:
  Add aria-label to icon buttons, aria-hidden to decorative SVGs, keyboard handlers
  for custom buttons. 15 role=button elements lack keyboard support. Directive scores:
  H7=5, H11=5. Ref: docs/reports/T-411-refactoring-directive-scoring.md

status: work-completed
workflow_type: refactor
owner: human
horizon:
tags: [refactoring, html, watchtower, usability, accessibility]
components: [web/templates/_partials/chat_tab.html, 
      web/templates/task_detail.html]
related_tasks: [T-411]
created: 2026-03-10T21:04:11Z
last_update: '2026-06-11T22:24:21Z'
date_finished: 2026-03-11T22:28:39Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:21Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-430: Template metadata component and accessibility improvements (H7+H11)

## Context

Template metadata + accessibility (H7+H11). See `docs/reports/T-411-refactoring-directive-scoring.md` § TEMPLATES rows H7 (metadata table, score 5), H11 (accessibility, score 5). H11 addresses 15 elements missing keyboard support and aria labels.

## Acceptance Criteria

### Agent
- [x] H11: Emoji buttons (fb-up, fb-down) have aria-label for screen readers
- [x] H11: Decorative chat emoji has aria-hidden="true"
- [x] H11: Health dot has aria-label="Provider status"
- [x] H11: Test button has aria-label="Test provider connection"
- [x] H11: Search gear icon has aria-label="LLM Settings"
- [x] H11: Clear recent searches button has aria-label
- [x] H11: Editable name/description have role="button" tabindex="0" for keyboard access
- [x] H11: Editable elements have onkeydown Enter handler
- [x] H10: inception_detail assumption status simplified (from T-429, carried over)
- [x] All affected pages load correctly after changes

### Human
- [x] [REVIEW] Keyboard navigation works on task detail page
  **Steps:**
  1. Open http://localhost:3000/tasks/T-428 in browser
  2. Tab to the task name — it should receive focus (visible outline)
  3. Press Enter — inline edit should activate
  **Expected:** Task name is focusable and Enter triggers edit mode
  **If not:** Check if tabindex="0" is present in page source

## Verification

# aria-labels present in search page
curl -s http://localhost:3000/search | grep -q 'aria-label="Provider status"'
curl -s http://localhost:3000/search | grep -q 'aria-label="Clear recent searches"'
curl -s http://localhost:3000/search | grep -q 'aria-label="LLM Settings"'
# Editable elements have keyboard support
curl -s http://localhost:3000/tasks/T-428 | grep -q 'role="button" tabindex="0"'
# Pages load
curl -sf http://localhost:3000/ > /dev/null
curl -sf http://localhost:3000/search > /dev/null
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

### 2026-03-10T21:04:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-430-template-metadata-component-and-accessib.md
- **Context:** Initial task creation

### 2026-03-11T22:23:31Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-11T22:28:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f6685466
- **Timestamp:** 2026-06-02T15:02:47Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 8

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 8
     - evidence: `curl -sf http://localhost:3000/ > /dev/null`
  2. **empty-output-success** (partial, heuristic) @ Verification:line 9
     - evidence: `curl -sf http://localhost:3000/search > /dev/null`
  3. **empty-output-success** (partial, heuristic) @ Verification:line 10
     - evidence: `curl -sf http://localhost:3000/tasks/T-428 > /dev/null`
  4. **empty-output-success** (partial, heuristic) @ Verification:line 11
     - evidence: `curl -sf http://localhost:3000/inception > /dev/null`
  5. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `curl -s http://localhost:3000/search | grep -q 'aria-label="Provider status"'`
  6. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `curl -s http://localhost:3000/search | grep -q 'aria-label="Clear recent searches"'`
  7. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `curl -s http://localhost:3000/search | grep -q 'aria-label="LLM Settings"'`
  8. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 6
     - evidence: `curl -s http://localhost:3000/tasks/T-428 | grep -q 'role="button" tabindex="0"'`

- **Suppressed:** 1 (by override)
  - human-ac-mechanical-signal @ AC#1 (Human)
