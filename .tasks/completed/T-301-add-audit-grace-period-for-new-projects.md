---
id: T-301
name: "Add audit grace period for new projects"
description: >
  fw audit shows 1 FAIL + 9 WARNs on brand-new projects. False positives: pre-framework commits without T-XXX (CTL-008/CTL-010), missing first handover (D8), missing cron dir (CTL-020). Fix: detect new project state (< 5 commits, no handover yet) and suppress known day-1 noise with INFO instead of FAIL/WARN. Separate from fw init artifact fixes (T-H). Source: T-294 simulation O-009.

status: work-completed
workflow_type: build
owner: agent
horizon: next
tags: []
components: [C-004]
related_tasks: [T-294]
created: 2026-03-04T16:17:08Z
last_update: 2026-03-04T18:30:25Z
date_finished: 2026-03-04T18:30:25Z
---

# T-301: Add audit grace period for new projects

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] New project detection: <5 commits + no handover = IS_NEW_PROJECT
- [x] grace_warn/grace_fail functions downgrade to info() for new projects
- [x] CTL-008, CTL-010, CTL-020, D8 use grace functions
- [x] Fresh project audit shows 0 warnings, 0 failures

## Verification

grep -q "grace_warn\|grace_fail" /opt/999-Agentic-Engineering-Framework/agents/audit/audit.sh
grep -q "IS_NEW_PROJECT" /opt/999-Agentic-Engineering-Framework/agents/audit/audit.sh

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

### 2026-03-04T18:25:41Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-04T18:30:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
