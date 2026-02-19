---
id: T-196
name: "Redesign cron schedule for OE testing (T-194 GO)"
description: >
  Replace/augment /etc/cron.d/agentic-audit with 4-tier OE schedule: 30min (oe-fast), hourly (oe-hourly), daily (oe-daily), weekly (oe-weekly). Preserve existing structural audit sections. Reference: docs/reports/T-194-control-register.md Phase 3 Proposed Cron Redesign.

status: captured
workflow_type: build
owner: claude-code
horizon: now
tags: [assurance, cron, t-194-go]
related_tasks: []
created: 2026-02-19T19:29:16Z
last_update: 2026-02-19T19:29:16Z
date_finished: null
---

# T-196: Redesign cron schedule for OE testing (T-194 GO)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

- [ ] [First criterion]
- [ ] [Second criterion]

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

### 2026-02-19T19:29:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-196-redesign-cron-schedule-for-oe-testing-t-.md
- **Context:** Initial task creation
