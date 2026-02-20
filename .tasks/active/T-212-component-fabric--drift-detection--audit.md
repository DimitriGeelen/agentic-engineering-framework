---
id: T-212
name: "Component Fabric — drift detection + audit integration"
description: >
  Implement fw fabric drift (unregistered, orphaned, stale edge detection) and add drift section to agents/audit/audit.sh. Related: T-191, T-208.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [component-fabric, drift, audit]
related_tasks: []
created: 2026-02-20T07:14:09Z
last_update: 2026-02-20T07:19:49Z
date_finished: null
---

# T-212: Component Fabric — drift detection + audit integration

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Implemented and tested


### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking. -->
<!-- Remove this section if all criteria are agent-verifiable. -->

## Verification
bash -c "fw audit --section structure 2>&1 | grep -c Fabric > /dev/null"

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

### 2026-02-20T07:14:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-212-component-fabric--drift-detection--audit.md
- **Context:** Initial task creation

### 2026-02-20T07:19:49Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
