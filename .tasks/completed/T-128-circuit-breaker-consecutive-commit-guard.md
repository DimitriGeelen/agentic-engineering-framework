---
id: T-128
name: "Circuit breaker: consecutive-commit guardrail"
description: >
  Addresses O-008. PostToolUse hook counts consecutive agent commits without user input. Warns after N.
status: work-completed
workflow_type: build
horizon: now
owner: agent
tags: []
related_tasks: []
created: 2026-02-17T20:03:13Z
last_update: 2026-02-18T06:16:57Z
date_finished: 2026-02-18T06:16:57Z
---

# T-128: Circuit breaker: consecutive-commit guardrail

## Context

Sprechloop cycle 2 revealed: agent chained 6 tasks with zero user check-in over a 2-hour build phase. The "Commit Cadence and Check-In" behavioral rule in CLAUDE.md was completely ignored. Evidence: L-013, L-038 — behavioral rules fail silently; only structural gates reliably enforce compliance.

**Design:** commit-msg hook checks `.context/working/.commit-counter` and blocks at threshold (3). post-commit hook increments the counter after each commit and warns at 2. `fw context init` resets counter on session start. Manual reset via `echo 0 > .context/working/.commit-counter` after user confirms.

## Acceptance Criteria

- [x] post-commit hook increments `.commit-counter` after every commit
- [x] post-commit hook shows NOTE at 2+ consecutive commits
- [x] commit-msg hook BLOCKS at 3+ consecutive commits with clear instructions
- [x] `fw context init` resets `.commit-counter` to 0
- [x] Hook templates in `agents/git/lib/hooks.sh` match installed hooks
- [x] CLAUDE.md documents the structural enforcement
- [x] Template (`lib/templates/claude-project.md`) matches CLAUDE.md

## Verification

# Counter file exists and is initialized
test -f .context/working/.commit-counter
# commit-msg hook contains circuit breaker logic
grep -q 'CIRCUIT BREAKER' .git/hooks/commit-msg
# post-commit hook contains counter increment
grep -q 'commit-counter' .git/hooks/post-commit
# Hook template matches installed hooks
grep -q 'CIRCUIT_BREAKER_THRESHOLD=3' agents/git/lib/hooks.sh
# Context init resets commit counter
grep -q 'commit-counter' agents/context/lib/init.sh
# CLAUDE.md documents the enforcement
grep -q 'T-128' CLAUDE.md

## Updates

### 2026-02-17T20:03:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-128-circuit-breaker-consecutive-commit-guard.md
- **Context:** Initial task creation

### 2026-02-17T23:49:26Z — status-update [task-update-agent]
- **Change:** horizon: next → now

### 2026-02-18T00:01:55Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-18T06:16:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
