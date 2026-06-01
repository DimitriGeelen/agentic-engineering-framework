---
id: T-602
name: "Fix multi-project cron collision — project-specific /etc/cron.d filenames"
description: >
  T-601 GO: Make fw audit schedule install use project-specific cron filenames instead of hardcoded /etc/cron.d/agentic-audit. Option D: basename with collision warning. Also fix schedule remove and schedule status.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-24T09:26:27Z
last_update: 2026-04-06T22:29:18Z
date_finished: 2026-03-24T09:29:53Z
---

# T-602: Fix multi-project cron collision — project-specific /etc/cron.d filenames

## Context

G-022 / T-601 GO. See `docs/reports/T-601-multi-project-cron-collision.md`.

## Acceptance Criteria

### Agent
- [x] Cron filename is project-specific (uses basename of PROJECT_ROOT) — `agentic-audit-999-agentic-engineering-framework`
- [x] `schedule install` warns if existing cron file points to different project (legacy migration + collision detection)
- [x] `schedule remove` removes project-specific cron file (tested: only target project removed)
- [x] `schedule status` shows cron for THIS project only (checks project-specific then legacy)
- [x] Two projects can have concurrent cron files in /etc/cron.d/ (verified: both coexist)

### Human
- [x] [RUBBER-STAMP] Run `fw audit schedule install` on 150-skills-manager and verify both cron files coexist
  **Steps:**
  1. On this machine: `ls /etc/cron.d/agentic-audit-*`
  2. Run `cd /opt/150-skills-manager && fw audit schedule install`
  3. Run `ls /etc/cron.d/agentic-audit-*` — should show TWO files
  **Expected:** `agentic-audit-999-Agentic-Engineering-Framework` and `agentic-audit-150-skills-manager`
  **If not:** Check that PROJECT_ROOT resolves correctly in consumer project

## Verification

# Project-specific filename used (not hardcoded)
grep -q 'project_slug' agents/audit/audit.sh
# Old hardcoded name no longer used
grep -q 'agentic-audit-' agents/audit/audit.sh

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

### 2026-03-24T09:26:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-602-fix-multi-project-cron-collision--projec.md
- **Context:** Initial task creation

### 2026-03-24T09:29:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-06T22:29:18Z — status-update [task-update-agent]
- **Change:** horizon: now → next
