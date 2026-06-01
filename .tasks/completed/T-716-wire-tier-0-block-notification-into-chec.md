---
id: T-716
name: "Wire Tier 0 block notification into check-tier0.sh"
description: >
  Wire Tier 0 block notification into check-tier0.sh

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-29T14:21:36Z
last_update: 2026-03-29T14:22:48Z
date_finished: 2026-03-29T14:22:48Z
---

# T-716: Wire Tier 0 block notification into check-tier0.sh

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `check-tier0.sh` sources `lib/notify.sh` and calls `fw_notify` on Tier 0 block (already wired by T-709)
- [x] Notification includes blocked command description and approval instructions (already in check-tier0.sh:405)
- [x] Notification fires only when actually blocked (not on pass-through) (exit 2 path only)
- [x] `update-task.sh` sends notification on human-AC partial-complete (already in update-task.sh:612)
- [x] `audit.sh` sends notification on FAIL results (already in audit.sh:3251)

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

### 2026-03-29T14:21:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-716-wire-tier-0-block-notification-into-chec.md
- **Context:** Initial task creation

### 2026-03-29T14:22:48Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
