---
id: T-266
name: "Streaming UX — marked.js, syntax highlighting, copy buttons"
description: >
  Replace custom renderAnswer() with marked.js for full CommonMark rendering. Add highlight.js for code syntax highlighting. Add copy buttons on code blocks. Improve thinking phase with progressive status messages and elapsed timer. Debounce markdown rendering to ~100ms intervals to prevent flicker. Add DOMPurify for XSS prevention. Files: web/templates/search.html (JS), web/static/ (marked.min.js, highlight.min.js, purify.min.js). Ref: docs/reports/T-261-arch-improvements.md §4 (full code sketches for marked integration, highlight, copy buttons, thinking phases). Predecessor: T-257 (frontend).

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [qa, frontend, ux]
components: []
related_tasks: []
created: 2026-02-24T08:37:26Z
last_update: 2026-02-24T08:37:26Z
date_finished: null
---

# T-266: Streaming UX — marked.js, syntax highlighting, copy buttons

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

### 2026-02-24T08:37:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-266-streaming-ux--markedjs-syntax-highlighti.md
- **Context:** Initial task creation
