---
id: T-006
name: Create episodic summary generator
description: >
  Per 010-TaskSystem.md: when task moves to work-completed, generate episodic summary.
  Build tool to extract timeline, pivots, learnings, outcome from completed tasks.
status: work-completed
workflow_type: build
owner: human
priority: medium
tags: [context-fabric, learning, tooling]
agents:
  primary:
  supporting: []
created: 2026-02-13T18:18:53Z
last_update: '2026-08-16T22:24:16Z'
date_finished: 2026-02-13T20:35:54Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:35Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:16Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 (no-signal); 
      F3=0 (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
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

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e1fcb490
- **Timestamp:** 2026-06-02T14:53:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
