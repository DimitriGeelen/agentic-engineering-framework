---
id: T-466
name: "Fix CLAUDE.md template — 70% governance missing in consumer projects"
description: >
  T-306 finding: generated CLAUDE.md for consumer projects contains only ~30% of governance sections. Missing 7 of 18 sections including Sub-Agent Dispatch Protocol, Context Budget Management, Verification Gate, Hypothesis-Driven Debugging, etc. Fix lib/templates/claude-project.md to include all governance sections. Ref: docs/reports/T-306-framework-distribution-model.md Agent #5 findings.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [init, template, T-306]
components: []
related_tasks: []
created: 2026-03-12T18:34:26Z
last_update: 2026-03-12T18:34:26Z
date_finished: null
---

# T-466: Fix CLAUDE.md template — 70% governance missing in consumer projects

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

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

### 2026-03-12T18:34:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-466-fix-claudemd-template--70-governance-mis.md
- **Context:** Initial task creation
