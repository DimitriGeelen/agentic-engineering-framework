---
id: T-302
name: "Complete fw init generated artifacts (cron dir, bypass-log, hooks)"
description: >
  fw init misses artifacts that cause audit warnings on day 1: (1) .context/audits/cron/ directory not created (CTL-020), (2) .context/bypass-log.yaml not created (CTL-010), (3) SessionStart:compact hook not in .claude/settings.json template (CTL-007). Fix: add mkdir for cron dir, create empty bypass-log.yaml, add SessionStart hook to settings.json generation in lib/init.sh. Source: T-294 simulation O-009.

status: work-completed
workflow_type: build
owner: agent
horizon: next
tags: []
components: [lib/init.sh]
related_tasks: [T-294]
created: 2026-03-04T16:18:55Z
last_update: 2026-03-04T18:33:44Z
date_finished: 2026-03-04T18:33:44Z
---

# T-302: Complete fw init generated artifacts (cron dir, bypass-log, hooks)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `fw init` creates `.context/audits/cron/` directory
- [x] `fw init` creates `.context/bypass-log.yaml` with empty bypasses array
- [x] `fw init` settings.json includes SessionStart:compact hook

## Verification

grep -q "audits/cron" /opt/999-Agentic-Engineering-Framework/lib/init.sh
grep -q "bypass-log.yaml" /opt/999-Agentic-Engineering-Framework/lib/init.sh
grep -q "SessionStart" /opt/999-Agentic-Engineering-Framework/lib/init.sh

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

### 2026-03-04T16:18:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-302-complete-fw-init-generated-artifacts-cro.md
- **Context:** Initial task creation

### 2026-03-04T18:30:35Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-04T18:33:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
