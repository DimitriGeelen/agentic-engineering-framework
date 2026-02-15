---
id: T-065
name: Create framework integration skill for plugin task-awareness
description: >
  T-061 finding: 0/20 loaded skills mention framework task creation. All major workflows (brainstorming, TDD, executing-plans, feature-dev) bypass the task system entirely. Design and create a framework-integration skill that: (1) detects .tasks/ directory presence, (2) requires active task before deferring to other skills, (3) loads with higher priority than using-superpowers, (4) wraps the skill invocation flow with task gates. This is a Tier D fix — changes ways of working.
status: started-work
workflow_type: design
owner: human
created: 2026-02-15T08:35:16Z
last_update: 2026-02-15T08:44:25Z
date_finished: null
---

# T-065: Create framework integration skill for plugin task-awareness

## Context

[Link to design docs, specs, or predecessor tasks]

## Updates

### 2026-02-15T08:35:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-065-create-framework-integration-skill-for-p.md
- **Context:** Initial task creation

### 2026-02-15T08:44:25Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
