---
id: T-387
name: "Add doc generator to cron jobs and test suite"
description: >
  Incorporate fw docs --all into the cron audit cycle (agents/audit/audit.sh) so component docs regenerate automatically. Also add to test suite to verify generation works. Triggered by T-364 doc generator being manual-only.

status: work-completed
workflow_type: build
owner: agent
horizon: next
tags: [docs, cron, automation]
components: []
related_tasks: []
created: 2026-03-09T11:11:06Z
last_update: 2026-03-09T14:06:36Z
date_finished: 2026-03-09T14:06:36Z
---

# T-387: Add doc generator to cron jobs and test suite

## Context

Add `fw docs --all` to the cron audit schedule so component reference docs regenerate automatically (daily at 8:15am). Add pytest test suite for the `generate_component.py` module covering unit and integration scenarios.

## Acceptance Criteria

### Agent
- [x] `fw docs --all` added to cron schedule in `audit.sh` (daily 8:15am)
- [x] Cron schedule summary updated to mention doc generation
- [x] Test file `agents/docgen/test_docgen.py` with 5 passing tests
- [x] Tests cover: basic generation, dependencies, empty cards, docs field, real fabric integration

## Verification

python3 -m pytest agents/docgen/test_docgen.py -v
grep -q "docs --all" agents/audit/audit.sh
grep -q "T-387" agents/audit/audit.sh

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

### 2026-03-09T11:11:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-387-add-doc-generator-to-cron-jobs-and-test-.md
- **Context:** Initial task creation

### 2026-03-09T14:00:49Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-09T14:06:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
