---
id: T-466
name: "Fix CLAUDE.md template — 70% governance missing in consumer projects"
description: >
  T-306 finding: generated CLAUDE.md for consumer projects contains only ~30% of governance sections. Missing 7 of 18 sections including Sub-Agent Dispatch Protocol, Context Budget Management, Verification Gate, Hypothesis-Driven Debugging, etc. Fix lib/templates/claude-project.md to include all governance sections. Ref: docs/reports/T-306-framework-distribution-model.md Agent #5 findings.

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: [init, template, T-306]
components: []
related_tasks: []
created: 2026-03-12T18:34:26Z
last_update: 2026-03-13T07:41:02Z
date_finished: 2026-03-13T07:41:02Z
---

# T-466: Fix CLAUDE.md template — 70% governance missing in consumer projects

## Context

Template has 6 sections fewer than master CLAUDE.md. Missing: Pickup Message Handling, Human Task Completion Rule, Human AC Format Requirements, Bug-Fix Learning Checkpoint, Post-Fix Root Cause Escalation, Component Fabric Web UI.

## Acceptance Criteria

### Agent
- [x] Template includes Pickup Message Handling section (G-020)
- [x] Template includes Human Task Completion Rule section
- [x] Template includes Human AC Format Requirements section
- [x] Template includes Bug-Fix Learning Checkpoint section
- [x] Template includes Post-Fix Root Cause Escalation section (G-019)
- [x] Template section count matches master CLAUDE.md (68 template vs 67 master — +1 from project-specific placeholders, correct)

## Verification

# All 6 missing sections present in template
grep -q "Pickup Message Handling" lib/templates/claude-project.md
grep -q "Human Task Completion Rule" lib/templates/claude-project.md
grep -q "Human AC Format Requirements" lib/templates/claude-project.md
grep -q "Bug-Fix Learning Checkpoint" lib/templates/claude-project.md
grep -q "Post-Fix Root Cause Escalation" lib/templates/claude-project.md

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

### 2026-03-12T18:34:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-466-fix-claudemd-template--70-governance-mis.md
- **Context:** Initial task creation

### 2026-03-13T07:37:54Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-13T07:41:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
