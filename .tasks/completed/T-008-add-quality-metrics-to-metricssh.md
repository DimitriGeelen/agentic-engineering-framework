---
id: T-008
name: Add quality metrics to metrics.sh
description: >
  Current metrics only check existence (file exists, field present). Add quality heuristics: description length, Updates entry count, acceptance criteria completion rate. Per P-004.
status: work-completed
workflow_type: build
owner: human
priority: medium
tags: [metrics, quality, D2]
agents:
  primary:
  supporting: []
created: 2026-02-13T18:19:01Z
last_update: 2026-02-13T21:25:00Z
date_finished: 2026-02-13T20:36:06Z
---

# T-008: Add quality metrics to metrics.sh

## Design Record

### Quality Metrics to Add

Per P-004 (distinguish existence from quality), add:
1. **Description quality** — Average description length, % with >50 chars
2. **Updates health** — Average updates per active task, stale task count
3. **Acceptance criteria** — % of tasks with defined AC, completion rate
4. **Design/Spec coverage** — % with non-empty Design Record, Specification Record
5. **Context Fabric health** — Patterns, learnings, episodic summary counts

### Output Format

Add new section `=== QUALITY METRICS ===` between existing sections.

## Specification Record

### Acceptance Criteria

- [x] Add description quality metrics (avg length, % quality)
- [x] Add updates health metrics (avg updates, stale count)
- [x] Add acceptance criteria metrics (coverage, completion)
- [x] Add Context Fabric metrics (patterns, learnings, episodic)
- [x] Format output consistently with existing metrics.sh style

## Test Files

- Run `./metrics.sh` and verify new section appears

## Updates

### 2026-02-13T18:19:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-008-add-quality-metrics-to-metricssh.md
- **Context:** Initial task creation

### 2026-02-13T21:25:00Z — started-work [claude-code]
- **Action:** Set status to started-work, defined quality metrics design
- **Context:** Working on T-006, T-007, T-008 together

### 2026-02-13T21:35:00Z — implementation-complete [claude-code]
- **Action:** Added quality metrics and Context Fabric metrics to metrics.sh
- **Output:**
  - Description quality (% >= 50 chars, avg length)
  - Updates health (avg updates/task, stale count)
  - Acceptance criteria coverage and completion
  - Context Fabric counts (patterns, learnings, decisions, episodic)
- **Context:** Fixed multiline description parsing, fixed bash (()) exit codes
