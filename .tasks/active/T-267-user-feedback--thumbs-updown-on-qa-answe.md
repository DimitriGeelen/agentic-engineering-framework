---
id: T-267
name: "User feedback — thumbs up/down on Q&A answers"
description: >
  Add subtle thumbs up/down buttons after Q&A answers. Store feedback in SQLite: query, answer, model, sources, rating (-1/0/1), optional comment, timestamp. POST /search/feedback endpoint. Basic analytics: GET /search/feedback/analytics showing total queries, positive/negative ratio, recent feedback. Enables quality tracking and prompt engineering iteration. Files: web/qa_feedback.py (NEW ~50 lines), web/blueprints/discovery.py (endpoints), web/templates/search.html (buttons), web/templates/feedback_analytics.html (NEW). Ref: docs/reports/T-261-arch-improvements.md §3 (full schema, endpoint code, frontend integration). Predecessor: T-257 (frontend).

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [qa, feedback, analytics]
components: []
related_tasks: []
created: 2026-02-24T08:37:37Z
last_update: 2026-02-24T08:37:37Z
date_finished: null
---

# T-267: User feedback — thumbs up/down on Q&A answers

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] [First criterion]
- [ ] [Second criterion]

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking. -->
<!-- Remove this section if all criteria are agent-verifiable. -->

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     Examples:
       python3 -c "import yaml; yaml.safe_load(open('path/to/file.yaml'))"
       curl -sf http://localhost:3000/page
       grep -q "expected_string" output_file.txt
-->

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
