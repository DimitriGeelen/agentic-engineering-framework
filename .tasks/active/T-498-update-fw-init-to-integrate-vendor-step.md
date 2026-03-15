---
id: T-498
name: "Update fw init to integrate vendor step"
description: >
  Modify fw init to: (1) copy framework into project/.agentic-framework/ as part of initialization, (2) generate settings.json with hooks pointing to .agentic-framework/bin/fw hook <name> instead of fw hook <name>, (3) remove framework_path from .framework.yaml (fw resolves from own location), (4) support all three scenarios: new project, existing codebase, post-clone. From T-482 GO.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [portability, isolation, P0]
components: []
related_tasks: []
created: 2026-03-15T14:01:10Z
last_update: 2026-03-15T14:01:10Z
date_finished: null
---

# T-498: Update fw init to integrate vendor step

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

### 2026-03-15T14:01:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-498-update-fw-init-to-integrate-vendor-step.md
- **Context:** Initial task creation
