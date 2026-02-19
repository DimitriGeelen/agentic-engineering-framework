---
id: T-199
name: "R-023 remediation — hook config validator in fw doctor"
description: >
  Build a hook configuration validator as part of fw doctor. Parses .claude/settings.json and verifies: hook structure is correct (nested format), all expected hooks are present, matcher patterns are valid, referenced scripts exist and are executable. R-023 (hook config fails silently, score 10 HIGH) has no control. Reference: Phase 2c recommendation.

status: work-completed
workflow_type: build
owner: claude-code
horizon: now
tags: [assurance, risk-remediation, t-194-go]
related_tasks: []
created: 2026-02-19T19:29:26Z
last_update: 2026-02-19T19:41:19Z
date_finished: 2026-02-19T19:41:19Z
---

# T-199: R-023 remediation — hook config validator in fw doctor

## Context

R-023 (hook config fails silently, score 10 HIGH) had zero controls. This adds a structural validator to `fw doctor` that catches the exact failure mode: flat JSON format, missing inner hooks array, script not found/executable, expected hooks not present.

## Acceptance Criteria

- [x] `fw doctor` validates settings.json hook structure (nested format)
- [x] Detects missing/non-executable referenced scripts
- [x] Checks 5 expected hooks are present (check-active-task, check-tier0, budget-gate, checkpoint, error-watchdog)
- [x] Reports OK/WARN/FAIL with actionable messages

## Verification

fw doctor 2>&1 | grep -q 'Hook configuration valid'

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

### 2026-02-19T19:29:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-199-r-023-remediation--hook-config-validator.md
- **Context:** Initial task creation

### 2026-02-19T19:39:54Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-19T19:41:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
