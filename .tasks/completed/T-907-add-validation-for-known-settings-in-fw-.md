---
id: T-907
name: "Add validation for known settings in fw config set"
description: >
  Add validation for known settings in fw config set

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/config-file.sh, tests/unit/lib_config_file.bats]
related_tasks: []
created: 2026-04-05T14:02:14Z
last_update: 2026-04-05T14:03:58Z
date_finished: 2026-04-05T14:03:58Z
---

# T-907: Add validation for known settings in fw config set

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Known integer settings (PORT, CONTEXT_WINDOW, etc.) warn if value is not numeric
- [x] Warning is informational only (set still succeeds — no blocking)
- [x] Test: `fw config set PORT banana` shows warning but sets the value

### Human
<!-- No human ACs
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

### 2026-04-05T14:02:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-907-add-validation-for-known-settings-in-fw-.md
- **Context:** Initial task creation

### 2026-04-05T14:03:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
