---
id: T-236
name: "Wire agent fabric awareness — blast-radius in git hooks, auto-capture learnings on completion"
description: >
  Wire Component Fabric and Context Fabric into agent workflows. Priority 1: Add blast-radius check to git commit flow (warn when modifying files with many dependents). Priority 2: Auto-extract decisions/patterns from task file on work-completed. Priority 3: Update CLAUDE.md Working with Tasks section to include fabric/context checks. Research: docs/reports/T-235-agent-fabric-awareness-vector-db.md, /tmp/fw-agent-fabric-awareness.md

status: captured
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-02-21T21:48:24Z
last_update: 2026-02-21T21:48:24Z
date_finished: null
---

# T-236: Wire agent fabric awareness — blast-radius in git hooks, auto-capture learnings on completion

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] [First criterion]
- [ ] [Second criterion]

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking. -->
<!-- Remove this section if all criteria are agent-verifiable. -->

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

### 2026-02-21T21:48:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-236-wire-agent-fabric-awareness--blast-radiu.md
- **Context:** Initial task creation
