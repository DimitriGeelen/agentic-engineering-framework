---
id: T-301
name: "Add audit grace period for new projects"
description: >
  fw audit shows 1 FAIL + 9 WARNs on brand-new projects. False positives: pre-framework commits without T-XXX (CTL-008/CTL-010), missing first handover (D8), missing cron dir (CTL-020). Fix: detect new project state (< 5 commits, no handover yet) and suppress known day-1 noise with INFO instead of FAIL/WARN. Separate from fw init artifact fixes (T-H). Source: T-294 simulation O-009.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: []
components: []
related_tasks: [T-294]
created: 2026-03-04T16:17:08Z
last_update: 2026-03-04T16:17:08Z
date_finished: null
---

# T-301: Add audit grace period for new projects

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

### 2026-03-04T16:17:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-301-add-audit-grace-period-for-new-projects.md
- **Context:** Initial task creation
