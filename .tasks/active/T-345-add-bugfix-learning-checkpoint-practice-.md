---
id: T-345
name: "Add bugfix learning checkpoint practice and G-016 gap"
description: >
  Add bugfix learning checkpoint practice and G-016 gap

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [meta, learning, practices]
components: []
related_tasks: []
created: 2026-03-08T12:25:51Z
last_update: 2026-03-08T12:25:51Z
date_finished: null
---

# T-345: Add bugfix learning checkpoint practice and G-016 gap

## Context

Deep analysis of learning capture gap (G-016): 72% of bugfix tasks produce zero learnings.
Research report: `/tmp/fw-agent-learning-gap-analysis.md`

## Acceptance Criteria

### Agent
- [x] Bug-Fix Learning Checkpoint practice added to CLAUDE.md under Agent Behavioral Rules
- [x] G-016 registered in gaps.yaml with evidence, trigger, and resolution options
- [x] Three learnings captured from T-344 fix cycle (L-078, L-079, L-080)

## Verification

grep -q "Bug-Fix Learning Checkpoint" CLAUDE.md
grep -q "G-016" .context/project/gaps.yaml
grep -q "L-078" .context/project/learnings.yaml

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

### 2026-03-08T12:25:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-345-add-bugfix-learning-checkpoint-practice-.md
- **Context:** Initial task creation
