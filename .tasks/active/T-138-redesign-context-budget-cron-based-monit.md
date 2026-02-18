---
id: T-138
name: Redesign context budget: cron-based monitor + PreToolUse enforcement
description: >
  Redesign context budget: cron-based monitor + PreToolUse enforcement
status: started-work
workflow_type: inception
horizon: now
owner: agent
tags: []
related_tasks: []
created: 2026-02-18T07:02:20Z
last_update: 2026-02-18T07:03:58Z
date_finished: null
---

# T-138: Redesign context budget: cron-based monitor + PreToolUse enforcement

## Context

Current budget system failed catastrophically in sprechloop cycle 3 (25 handover commits in 10min) and in this session (agent at 80%/160K tokens, never checked once). Root cause: PostToolUse hooks run inside the agent's loop — agent controls when they fire and can ignore warnings. Commit counters measure the wrong metric.

Inception findings: `docs/T-138-inception-findings.md`
- 11 flaws in current system (3 critical)
- Cron + PreToolUse design proposed
- Portability concern: hybrid approach recommended (cron optional, PostToolUse fallback)
- Go/no-go decision: PENDING

## Go/No-Go Criteria

- [ ] Decision on approach: pure cron vs hybrid (keep PostToolUse as fallback)
- [ ] Decision on portability: accept Linux-only cron or require cross-platform
- [ ] Prototype budget-gate.sh (PreToolUse hook) to validate exit-code-2 blocking works
- [ ] Record decision via `fw inception decide T-138 go|no-go`

## Updates

### 2026-02-18T07:02:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-138-redesign-context-budget-cron-based-monit.md
- **Context:** Initial task creation

### 2026-02-18T07:03:53Z — status-update [task-update-agent]
- **Change:** status: started-work → captured

### 2026-02-18T07:03:58Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
