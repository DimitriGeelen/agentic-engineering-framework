---
id: T-249
name: "Refine D5 lifecycle anomaly detection to reduce false positive rate"
description: >
  D5 lifecycle anomaly detection flags legitimate human admin tasks at roughly half FP rate. Needs refinement: filter by workflow_type or add owner: agenthuman plus fast-completion as expected pattern. GO criterion was under 20 pct FP. Research: docs/reports/T-200-discovery-layer-design.md Phase 3. Related: T-200, T-239.

status: captured
workflow_type: build
owner:
horizon: later
tags: []
components: []
related_tasks: []
created: 2026-02-22T09:42:05Z
last_update: 2026-02-22T09:42:05Z
date_finished: null
---

# T-249: Refine D5 lifecycle anomaly detection to reduce false positive rate

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

### 2026-02-22T09:42:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-249-refine-d5-lifecycle-anomaly-detection-to.md
- **Context:** Initial task creation
