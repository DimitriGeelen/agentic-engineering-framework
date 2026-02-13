---
id: T-007
name: Implement healing loop mechanism
description: >
  Per 010-TaskSystem.md: when task status changes to issues, healing loop should activate - classify failure, suggest recovery, log pattern. Currently specified but not implemented.
status: work-completed
workflow_type: build
owner: human
priority: medium
tags: [antifragility, D1, error-handling]
agents:
  primary:
  supporting: []
created: 2026-02-13T18:18:55Z
last_update: 2026-02-13T21:25:00Z
date_finished: null
---

# T-007: Implement healing loop mechanism

## Design Record

### Healing Loop Concept

Per 010-TaskSystem.md, when a task transitions to "issues" status:
1. **Classify** — What type of failure? (code error, dependency, environment, design)
2. **Lookup** — Are there existing patterns for this failure type?
3. **Suggest** — Recommend recovery actions based on patterns
4. **Log** — Record the issue for future pattern learning

### Architecture

Create a `healing` agent with commands:
- `diagnose T-XXX` — Analyze task's issues, suggest recovery
- `resolve T-XXX` — Mark issue as resolved, log pattern
- `patterns` — Show known failure patterns and mitigations

The agent reads from `.context/project/patterns.yaml` (failure_patterns) and writes new patterns when issues are resolved.

### Error Escalation Ladder Integration

Per CLAUDE.md, graduated response:
- **A** — Don't repeat the same failure (lookup existing patterns)
- **B** — Improve technique (suggest better approach)
- **C** — Improve tooling (suggest automation)
- **D** — Change ways of working (suggest process change)

## Specification Record

### Acceptance Criteria

- [x] Create healing agent with diagnose command
- [x] Lookup similar patterns from patterns.yaml
- [x] Classify failure type (code, dependency, environment, design)
- [x] Suggest recovery actions based on patterns
- [x] Create resolve command to log resolution
- [x] Add new failure pattern when issue is resolved
- [x] Document in AGENT.md

## Test Files

- Manual test: create task with issues status, run diagnose

## Updates

### 2026-02-13T18:18:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-007-implement-healing-loop-mechanism.md
- **Context:** Initial task creation

### 2026-02-13T21:25:00Z — started-work [claude-code]
- **Action:** Set status to started-work, defined healing loop design
- **Context:** Working on T-006, T-007, T-008 together

### 2026-02-13T21:35:00Z — implementation-complete [claude-code]
- **Action:** Created healing agent with 4 commands
- **Output:**
  - `diagnose` - Classifies failures, looks up patterns, suggests recovery
  - `resolve` - Records resolution as pattern + learning
  - `patterns` - Shows all failure patterns with mitigations
  - `suggest` - Checks all tasks with issues status
- **Context:** Implements Error Escalation Ladder (A-B-C-D) from CLAUDE.md
