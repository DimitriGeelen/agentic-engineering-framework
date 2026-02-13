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
last_update: 2026-02-13T13:30:00Z
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
- [x] .tasks/ structure exists and is in use
- [x] metrics.sh can report basic counts
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

### 2026-02-13 12:30 — infrastructure-created [claude-code]
- **Action:** Created .tasks/ structure, metrics.sh, committed with T-001 reference
- **Output:** Commit cb929d6. Traceability: 0% → 50%
- **Context:** First observable metric change from using the framework.

### 2026-02-13 13:00 — learning-extracted [claude-code]
- **Action:** Reflected on what we did vs. what we originally planned
- **Learning:** "Measure what exists, not what should exist"
- **Pattern:** We failed at theoretical metrics → pivoted to experimentation → observed real data → learning emerged
- **Promoted to:** 015-Practices.md (P-001)
- **Context:** This is an instance of D1 (Antifragility) in action — learning from doing.

### 2026-02-13 13:30 — context-captured [claude-code]
- **Action:** Created 001-Vision.md to capture full context of success question journey
- **Output:** Vision doc with: problem, vision, success question history, current state, staged success criteria, open questions
- **Why:** Risk of losing context between sessions. The success question is bigger than T-001 — needed project-level documentation.
- **Context:** Now have clear record of: what we tried, why it failed, what we pivoted to, where we are, what's next.
