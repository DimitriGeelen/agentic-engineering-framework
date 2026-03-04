---
id: T-318
name: "Write AGENT.md for onboarding test interpretation"
description: >
  Write agents/onboarding-test/AGENT.md with AI interpretation criteria for test-onboarding output. Covers: day-1 noise vs real failures, CLAUDE.md quality assessment, partial failure diagnosis, focus state verification. From T-307 GO decision.

status: work-completed
workflow_type: build
owner: agent
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-03-04T21:22:54Z
last_update: 2026-03-04T21:44:54Z
date_finished: 2026-03-04T21:44:54Z
---

# T-318: Write AGENT.md for onboarding test interpretation

## Context

From T-307 inception GO. Companion to T-317 (deterministic script). See `docs/reports/T-307-hybrid-onboarding-test.md`.

## Acceptance Criteria

### Agent
- [x] `agents/onboarding-test/AGENT.md` exists
- [x] Covers all 8 checkpoints (C1-C8) with interpretation criteria
- [x] Distinguishes day-1 noise from real failures for each checkpoint
- [x] Includes diagnostic patterns for cascading failures
- [x] Includes quality assessment criteria beyond pass/fail
- [x] Provides structured output format for agent reports

## Verification

test -f agents/onboarding-test/AGENT.md
grep -q "C1: Project Scaffold" agents/onboarding-test/AGENT.md
grep -q "C8: Handover" agents/onboarding-test/AGENT.md
grep -q "Day-1 noise" agents/onboarding-test/AGENT.md
grep -q "Cascading Failures" agents/onboarding-test/AGENT.md
grep -q "Quality Assessment" agents/onboarding-test/AGENT.md

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

### 2026-03-04T21:22:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-318-write-agentmd-for-onboarding-test-interp.md
- **Context:** Initial task creation

### 2026-03-04T21:41:19Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-04T21:44:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
