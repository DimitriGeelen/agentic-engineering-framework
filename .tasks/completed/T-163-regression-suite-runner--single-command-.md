---
id: T-163
name: "Regression suite runner — single command to validate framework health"
description: >
  Create fw test command that runs: ShellCheck on all .sh files, bats unit tests, bats integration tests, pytest web tests, test-tier0-patterns.py. Report: pass/fail/skip counts, coverage summary. Integrate with fw doctor (add test check). Consider pre-push hook integration. Ref: T-158

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T13:30:57Z
last_update: 2026-02-18T15:28:16Z
date_finished: 2026-02-18T15:28:16Z
---

# T-163: Regression suite runner — single command to validate framework health

## Context

T-159/T-160/T-161 built test infrastructure and tests. This task wires the single-command runner and doctor integration.

## Acceptance Criteria

- [x] `fw test` runs all suites (unit + integration + web) — done in T-159
- [x] `fw test unit` / `fw test integration` / `fw test web` / `fw test lint` — done in T-159
- [x] `fw doctor` reports test infrastructure status (bats count, shellcheck)
- [x] `fw test` help shows available sub-commands

## Verification

fw doctor 2>&1 | grep -q "Test infrastructure"
fw test unit
fw test help 2>&1 | grep -q "integration"

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

### 2026-02-18T13:30:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-163-regression-suite-runner--single-command-.md
- **Context:** Initial task creation

### 2026-02-18T15:28:16Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
