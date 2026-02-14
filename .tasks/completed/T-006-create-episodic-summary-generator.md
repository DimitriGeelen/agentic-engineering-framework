---
id: T-006
name: Create episodic summary generator
description: >
  Per 010-TaskSystem.md: when task moves to work-completed, generate episodic summary. Build tool to extract timeline, pivots, learnings, outcome from completed tasks.
status: work-completed
workflow_type: build
owner: human
priority: medium
tags: [context-fabric, learning, tooling]
agents:
  primary:
  supporting: []
created: 2026-02-13T18:18:53Z
last_update: 2026-02-13T21:25:00Z
date_finished: 2026-02-13T20:35:54Z
---

# T-006: Create episodic summary generator

## Design Record

### Approach

Enhance the existing `generate-episodic` command in the context agent to:
1. Parse task file more intelligently (extract from Updates section)
2. Identify challenges/pivots from status changes
3. Extract learnings from resolution patterns
4. Generate richer summary automatically

### Integration

The generator can be:
- Called manually: `./agents/context/context.sh generate-episodic T-XXX`
- Called automatically when task moves to completed (future enhancement)

## Specification Record

### Acceptance Criteria

- [x] Parse Updates section to extract timeline events
- [x] Identify challenges (status changes to issues/blocked)
- [x] Extract outcomes from final state
- [x] Generate summary from description + updates
- [x] Count artifacts (files created/modified from updates)
- [x] Enrich episodic YAML with parsed data

## Test Files

- Test with T-013, T-014, T-005 (completed tasks with rich updates)

## Updates

### 2026-02-13T18:18:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-006-create-episodic-summary-generator.md
- **Context:** Initial task creation

### 2026-02-13T21:25:00Z — started-work [claude-code]
- **Action:** Set status to started-work, defined acceptance criteria
- **Context:** Working on T-006, T-007, T-008 together

### 2026-02-13T21:35:00Z — implementation-complete [claude-code]
- **Action:** Enhanced generate-episodic command in context agent
- **Output:** Parses Updates section, extracts acceptance criteria, identifies challenges, extracts file references
- **Context:** Now auto-populates episodic summaries with richer data
