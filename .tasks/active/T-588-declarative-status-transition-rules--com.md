---
id: T-588
name: "Declarative status transition rules — compiled ACL pattern for task state machine"
description: >
  Currently update-task.sh has inline case/esac logic for allowed status transitions. OpenClaw compiles declarative scope groups to O(1) Map lookup at startup (method-scopes.ts, 20 LOC compilation). Adopt: declare allowed transitions in status-transitions.yaml, compile to lookup, validate in update-task.sh. Benefits: visible rules (anyone can read YAML), verifiable (fw doctor validates no orphaned states), extensible (edit YAML not bash), auditable (Watchtower displays state machine). Connects to T-511 governance.yaml (another governance declaration). Implementation language pending T-586. Research source: /opt/openclaw-evaluation/.context/working/round2-T-022.md (Pattern 4, rated 5 stars directly adoptable). OpenClaw source: src/gateway/method-scopes.ts. Related: T-586 (language strategy), T-511 (governance.yaml), agents/task-create/update-task.sh (current inline logic).

status: captured
workflow_type: build
owner: agent
horizon: later
tags: []
components: []
related_tasks: []
created: 2026-03-23T21:35:28Z
last_update: 2026-03-23T21:35:28Z
date_finished: null
---

# T-588: Declarative status transition rules — compiled ACL pattern for task state machine

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

### 2026-03-23T21:35:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-588-declarative-status-transition-rules--com.md
- **Context:** Initial task creation
