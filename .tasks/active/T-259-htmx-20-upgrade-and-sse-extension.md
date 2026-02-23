---
id: T-259
name: "htmx 2.0+ upgrade and SSE extension"
description: >
  Verify current htmx version in web/static/htmx.min.js. If <2.0, upgrade to 2.0+. Add htmx SSE extension (sse.js) to static/. Load in base.html. Test existing htmx interactions still work after upgrade. See docs/reports/T-254-llm-assisted-qa-research.md RQ-3 (htmx version check needed). Predecessor: none (can run in parallel).

status: captured
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-254]
created: 2026-02-23T20:38:59Z
last_update: 2026-02-23T20:38:59Z
date_finished: null
---

# T-259: htmx 2.0+ upgrade and SSE extension

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

### 2026-02-23T20:38:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-259-htmx-20-upgrade-and-sse-extension.md
- **Context:** Initial task creation
