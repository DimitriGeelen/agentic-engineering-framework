---
id: T-001
name: Define measurable success metrics
description: >
  Experiment with the framework to gather real usage data,
  then define concrete, measurable success criteria based on
  what we learn. Avoid semantic/fake metrics - only metrics
  we can actually observe and count.
status: started-work
workflow_type: specification
owner: human
priority: high
tags: [meta, metrics, bootstrap]
agents:
  primary: claude-code
  supporting: []
created: 2026-02-13T12:00:00Z
last_update: 2026-02-13T12:00:00Z
date_finished: null
---

# T-001: Define measurable success metrics

## Design Record

Approach: Experiential learning over upfront design.

1. Create task structure and use it
2. Build minimal metrics.sh to observe what exists
3. Identify what data is actually collectible
4. Define metrics from observed reality, not theory

Key insight from critical review: We were measuring "compliance artifacts" not "outcomes".
Must distinguish between:
- Existence metrics (file exists) - easily gamed
- Quality metrics (content is useful) - harder to measure
- Outcome metrics (did it help?) - requires time

## Specification Record

Acceptance criteria:
- [ ] .tasks/ structure exists and is in use
- [ ] metrics.sh can report basic counts
- [ ] At least 3 tasks created and progressed through lifecycle
- [ ] Success metrics documented with: metric, collection method, baseline, target
- [ ] Identified at least one metric we thought we could measure but can't

## Test Files

N/A - this is a specification task

## Updates

### 2026-02-13 12:00 — task-created [claude-code]
- **Action:** Created T-001 as first framework task (bootstrapping)
- **Output:** .tasks/active/T-001-define-success-metrics.md
- **Context:** Following critical review from 3 agents. Pivoting from theoretical metrics to experimental approach.
