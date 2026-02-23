---
id: T-257
name: "Frontend — Ask Q&A section with htmx SSE streaming"
description: >
  Add Ask Q&A section to web/templates/search.html: textarea input, Ask button, answer div with streaming token display, collapsible Sources panel with inline [1][2] citations. Uses htmx 2.0+ SSE extension (hx-ext=sse, sse-connect). Reuses T-253 URL mapping for source links. ~80 lines template + check/upgrade htmx version. See docs/reports/T-254-llm-assisted-qa-research.md RQ-3. Predecessor: T-256.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-254]
created: 2026-02-23T20:38:34Z
last_update: 2026-02-23T20:38:34Z
date_finished: null
---

# T-257: Frontend — Ask Q&A section with htmx SSE streaming

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

### 2026-02-23T20:38:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-257-frontend--ask-qa-section-with-htmx-sse-s.md
- **Context:** Initial task creation
