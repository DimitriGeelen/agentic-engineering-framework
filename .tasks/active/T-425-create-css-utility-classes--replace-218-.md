---
id: T-425
name: "Create CSS utility classes — replace 218 inline styles across templates and JS (J1+H1)"
description: >
  218 inline style attributes across 30+ templates. Create utility classes (.text-muted, .text-xs, .flex, .gap-*, .mb-*) in base.html style block. Replace inline styles in templates and hardcoded colors in JS (#2e7d32, #c62828). Directive scores: J1=5, H1=5. Ref: docs/reports/T-411-refactoring-directive-scoring.md

status: captured
workflow_type: refactor
owner: agent
horizon: next
tags: [refactoring, css, watchtower, usability]
components: []
related_tasks: [T-411]
created: 2026-03-10T21:04:06Z
last_update: 2026-03-10T21:04:06Z
date_finished: null
---

# T-425: Create CSS utility classes — replace 218 inline styles across templates and JS (J1+H1)

## Context

CSS utility classes (J1+H1). See `docs/reports/T-411-refactoring-directive-scoring.md` § JS row J1 (score 5) and TEMPLATES row H1 (score 5). 218 inline style attributes across 30+ templates. Largest visual impact but lowest directive score — pure usability play.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] [First criterion]
- [ ] [Second criterion]

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

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

### 2026-03-10T21:04:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-425-create-css-utility-classes--replace-218-.md
- **Context:** Initial task creation
