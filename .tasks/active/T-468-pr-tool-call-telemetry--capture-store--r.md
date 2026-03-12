---
id: T-468
name: "Inception: Tool call telemetry — scope capture store + Watchtower reporting"
description: >
  Inception: Scope the tool call telemetry feature from 010-termlink. Source files exist
  (extractor, hook, stats, error analyzer) but Watchtower page, CLI routing, hook
  registration, and handover integration are new build work requiring design.

status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-12T18:36:18Z
last_update: 2026-03-12T18:40:53Z
date_finished: null
---

# T-468: PR: Tool call telemetry — capture store + reporting from 010-termlink

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

### 2026-03-12T18:36:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-468-pr-tool-call-telemetry--capture-store--r.md
- **Context:** Initial task creation

### 2026-03-12T18:40:53Z — status-update [task-update-agent]
- **Change:** status: started-work → issues
- **Reason:** Jumped to building without inception. Need to scope: source files exist in termlink (copy), but Watchtower page + CLI routing + hook registration + handover integration = new build work requiring inception.
