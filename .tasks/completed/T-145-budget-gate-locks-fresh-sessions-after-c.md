---
id: T-145
name: "Budget gate locks fresh sessions after compaction — JSONL accumulates"
description: >
  After /compact, the JSONL transcript retains all pre-compaction messages. budget-gate.sh reads the full file and sees 150K+ tokens, writing critical to .budget-status. Fresh sessions inherit this lock. The gate self-reinforces: each blocked call re-reads the JSONL and re-confirms critical. Fix: detect session boundaries (compaction markers) in JSONL, or base token count on actual active context, not historical transcript.

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T09:38:27Z
last_update: 2026-02-18T09:40:17Z
date_finished: 2026-02-18T09:40:17Z
---

# T-145: Budget gate locks fresh sessions after compaction — JSONL accumulates

## Context

Budget gate deadlock after compaction: stale `.budget-status` (critical) blocks `fw context init` which is the command that would reset the status.

## Acceptance Criteria

- [x] budget-gate.sh allowlist includes fw context init, fw resume, git status/log/diff
- [x] pre-compact.sh resets .budget-status and .budget-gate-counter before compaction
- [x] Regex allowlist passes 13/13 test cases

## Verification

grep -q 'context.s.init' agents/context/budget-gate.sh
grep -q 'budget-gate-counter' agents/context/pre-compact.sh
grep -q 'budget-status' agents/context/pre-compact.sh

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

### 2026-02-18T09:38:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-145-budget-gate-locks-fresh-sessions-after-c.md
- **Context:** Initial task creation

### 2026-02-18T09:40:17Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-18T09:40:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
