---
id: T-172
name: "Docs page — discover research docs, commands, and skills"
description: >
  Extend T-171 docs discovery to also surface: (1) Research/exploration artifacts — agent investigation outputs, spike results (spikes/), inception findings. (2) Claude Code commands (.claude/commands/*.md). (3) Skills definitions. Consider adding these as new categories alongside Governance/Design/Agents/Project.

status: started-work
workflow_type: build
owner: claude-code
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T18:11:20Z
last_update: 2026-02-19T00:02:34Z
date_finished: null
---

# T-172: Docs page — discover research docs, commands, and skills

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

- [x] Commands category discovers .claude/commands/*.md and shows them on /project page
- [x] Research category discovers .context/episodic/*.yaml (most recent 25) with task names
- [x] YAML files render as syntax-highlighted code blocks in the doc viewer
- [x] Existing 4 categories (Governance, Design, Agents, Project) unchanged
- [x] Page loads without errors

## Verification

curl -sf http://localhost:3000/project | grep -q "Commands"
curl -sf http://localhost:3000/project | grep -q "Research"
curl -sf http://localhost:3000/project/.context--episodic--T-182 | grep -q "yaml"

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

### 2026-02-18T18:11:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-172-docs-page--discover-research-docs-comman.md
- **Context:** Initial task creation

### 2026-02-18T23:22:50Z — status-update [task-update-agent]
- **Change:** horizon: next → now

### 2026-02-19T00:02:34Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
