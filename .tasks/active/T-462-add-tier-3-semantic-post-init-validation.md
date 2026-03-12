---
id: T-462
name: "Add Tier 3 semantic post-init validation"
description: >
  Extend validate-init.sh with semantic checks: governance files contain no framework-specific IDs (no D-030+, no L-068+), component fabric is empty (no framework internals), onboarding tasks reference project name not 'the framework', .framework.yaml has correct provider setting. These catch knowledge leakage — the core problem T-455 identified.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [init, validation, isolation]
components: []
related_tasks: []
created: 2026-03-12T17:01:01Z
last_update: 2026-03-12T17:01:01Z
date_finished: null
---

# T-462: Add Tier 3 semantic post-init validation

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

### 2026-03-12T17:01:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-462-add-tier-3-semantic-post-init-validation.md
- **Context:** Initial task creation
