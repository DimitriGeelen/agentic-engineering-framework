---
id: T-478
name: "Update context budget system for 1M token window (Opus 4.6 GA)"
description: >
  Anthropic announced 1M context GA for Opus 4.6/Sonnet 4.6 on 2026-03-13. Framework budget-gate.sh, checkpoint.sh, and CLAUDE.md all hardcode 200K window with thresholds at 120K/150K/170K. Update to reflect new 1M window while keeping sensible handover headroom.

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: [enforcement, budget, context]
components: []
related_tasks: []
created: 2026-03-14T11:54:22Z
last_update: 2026-03-14T11:58:49Z
date_finished: 2026-03-14T11:58:49Z
---

# T-478: Update context budget system for 1M token window (Opus 4.6 GA)

## Context

Anthropic announced 1M context GA for Opus 4.6/Sonnet 4.6 on 2026-03-13. No beta header required, no pricing premium. Framework budget-gate.sh, checkpoint.sh, and CLAUDE.md all hardcode 200K window with thresholds at 120K/150K/170K. These need updating to reflect the 5x larger window.

## Acceptance Criteria

### Agent
- [x] budget-gate.sh uses configurable CONTEXT_WINDOW (default 1M), thresholds derived from it
- [x] checkpoint.sh uses same configurable CONTEXT_WINDOW, thresholds derived from it
- [x] All hardcoded `200000` and `200K` references replaced in both scripts
- [x] CLAUDE.md Work Proposal Rule updated with new thresholds
- [x] CLAUDE.md escalation ladder updated with new thresholds
- [x] Both scripts pass bash -n syntax check

## Verification

bash -n agents/context/budget-gate.sh
bash -n agents/context/checkpoint.sh
# No hardcoded 200000 remaining in budget scripts
test "$(grep -c '200000' agents/context/budget-gate.sh)" = "0"
test "$(grep -c '200000' agents/context/checkpoint.sh)" = "0"
# CONTEXT_WINDOW variable exists in both
grep -q 'CONTEXT_WINDOW' agents/context/budget-gate.sh
grep -q 'CONTEXT_WINDOW' agents/context/checkpoint.sh
# CLAUDE.md references new thresholds
grep -q '600K' CLAUDE.md
grep -q '800K' CLAUDE.md
grep -q '900K' CLAUDE.md

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

### 2026-03-14T11:54:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-478-update-context-budget-system-for-1m-toke.md
- **Context:** Initial task creation

### 2026-03-14T11:58:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
