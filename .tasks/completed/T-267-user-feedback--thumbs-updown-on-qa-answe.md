---
id: T-267
name: "User feedback — thumbs up/down on Q&A answers"
description: >
  Add subtle thumbs up/down buttons after Q&A answers. Store feedback in SQLite: query,
  answer, model, sources, rating (-1/0/1), optional comment, timestamp. POST /search/feedback
  endpoint. Basic analytics: GET /search/feedback/analytics showing total queries,
  positive/negative ratio, recent feedback. Enables quality tracking and prompt engineering
  iteration. Files: web/qa_feedback.py (NEW ~50 lines), web/blueprints/discovery.py
  (endpoints), web/templates/search.html (buttons), web/templates/feedback_analytics.html
  (NEW). Ref: docs/reports/T-261-arch-improvements.md §3 (full schema, endpoint code,
  frontend integration). Predecessor: T-257 (frontend).

status: work-completed
workflow_type: build
owner: human
horizon: null
components: [C-003, web/templates/search.html]
related_tasks: []
created: 2026-02-24T08:37:37Z
last_update: '2026-06-11T22:24:17Z'
date_finished: 2026-02-24T10:14:41Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:17Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-267: User feedback — thumbs up/down on Q&A answers

## Context

Thumbs up/down feedback on Q&A answers for quality tracking. Ref: T-261 research §3.

## Acceptance Criteria

### Agent
- [x] web/qa_feedback.py with SQLite storage (save_feedback, get_analytics)
- [x] POST /search/feedback endpoint in discovery blueprint
- [x] GET /search/feedback/analytics endpoint with analytics template
- [x] Thumbs up/down buttons in search.html after answer completes
- [x] CSRF token included in feedback POST
- [x] Model name tracked and sent with feedback

### Human
- [x] Thumbs up/down buttons work in browser
- [x] Analytics page shows feedback data at /search/feedback/analytics

## Verification

# qa_feedback.py exists
test -f web/qa_feedback.py
# POST endpoint exists
grep -q "search/feedback" web/blueprints/discovery.py
# Analytics endpoint exists
grep -q "feedback_analytics" web/blueprints/discovery.py
# Analytics template exists
test -f web/templates/feedback_analytics.html
# Feedback buttons in search template
grep -q "sendFeedback" web/templates/search.html
# SQLite module imports correctly
python3 -c "from web.qa_feedback import save_feedback, get_analytics; print('OK')"

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

### 2026-02-24T08:37:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-267-user-feedback--thumbs-updown-on-qa-answe.md
- **Context:** Initial task creation

### 2026-02-24T10:10:27Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-24T10:14:41Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7ed81823
- **Timestamp:** 2026-06-02T15:01:48Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
