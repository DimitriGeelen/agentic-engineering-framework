---
id: T-196
name: "Redesign cron schedule for OE testing (T-194 GO)"
description: >
  Replace/augment /etc/cron.d/agentic-audit with 4-tier OE schedule: 30min (oe-fast), hourly (oe-hourly), daily (oe-daily), weekly (oe-weekly). Preserve existing structural audit sections. Reference: docs/reports/T-194-control-register.md Phase 3 Proposed Cron Redesign.

status: work-completed
workflow_type: build
owner: claude-code
horizon: now
tags: [assurance, cron, t-194-go]
related_tasks: []
created: 2026-02-19T19:29:16Z
last_update: 2026-02-19T19:39:33Z
date_finished: 2026-02-19T19:39:33Z
---

# T-196: Redesign cron schedule for OE testing (T-194 GO)

## Context

T-194 GO deliverable. Redesigned `/etc/cron.d/agentic-audit` with two tracks: structural audits (project well-formed) and OE audits (controls working). OE runs offset from structural to spread load.

## Acceptance Criteria

- [x] Cron schedule has OE tier entries (oe-fast, oe-hourly, oe-daily, oe-weekly)
- [x] Structural audit sections preserved (D-Phase3-003)
- [x] OE and structural runs offset to avoid concurrent execution
- [x] `fw audit schedule install` installs the new schedule

## Verification

grep -q 'oe-fast' /etc/cron.d/agentic-audit
grep -q 'oe-daily' /etc/cron.d/agentic-audit
grep -q 'oe-weekly' /etc/cron.d/agentic-audit
grep -q 'structure,compliance,quality' /etc/cron.d/agentic-audit

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

### 2026-02-19T19:38:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-19T19:39:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
