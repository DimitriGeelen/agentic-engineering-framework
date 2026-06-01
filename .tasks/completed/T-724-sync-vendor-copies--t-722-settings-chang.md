---
id: T-724
name: "Sync vendor copies — T-722 settings changes to .agentic-framework"
description: >
  Sync vendor copies — T-722 settings changes to .agentic-framework

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-29T19:40:55Z
last_update: 2026-03-29T19:42:31Z
date_finished: 2026-03-29T19:42:31Z
---

# T-724: Sync vendor copies — T-722 settings changes to .agentic-framework

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] .agentic-framework/web/blueprints/settings.py matches source web/blueprints/settings.py
- [x] .agentic-framework/web/templates/settings.html matches source web/templates/settings.html
- [x] Additional out-of-sync vendor files synced: lib/version.sh, agents/audit/self-audit.sh, agents/context/checkpoint.sh, bin/fw

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

### 2026-03-29T19:40:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-724-sync-vendor-copies--t-722-settings-chang.md
- **Context:** Initial task creation

### 2026-03-29T19:42:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
