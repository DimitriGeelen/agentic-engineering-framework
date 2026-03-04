---
id: T-308
name: "Create /new-project Claude Code skill"
description: >
  Claude Code skill wrapping fw init/setup for in-session guided onboarding. Agent says /new-project, skill walks through setup interactively. Source: T-294 Phase 3 item T-N, uncaptured during dialogue.

status: work-completed
workflow_type: build
owner: agent
horizon: later
tags: []
components: []
related_tasks: [T-294]
created: 2026-03-04T17:28:39Z
last_update: 2026-03-04T22:21:02Z
date_finished: 2026-03-04T22:21:02Z
---

# T-308: Create /new-project Claude Code skill

## Context

Claude Code skill wrapping `fw init` for in-session guided onboarding. Follows pattern of existing skills in `.claude/commands/`.

## Acceptance Criteria

### Agent
- [x] `.claude/commands/new-project.md` exists with step-by-step workflow
- [x] Skill asks for project path and provider before running init
- [x] Skill runs `fw init`, `fw doctor`, and `fw context init` in sequence
- [x] Skill ends with `fw work-on` to create the first task
- [x] Skill is listed in settings.json Skill tool section (auto-discovered)

## Verification

# Skill file exists
test -f .claude/commands/new-project.md
# Contains key workflow steps
grep -q "fw init" .claude/commands/new-project.md
grep -q "fw doctor" .claude/commands/new-project.md
grep -q "fw work-on" .claude/commands/new-project.md

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

### 2026-03-04T17:28:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-308-create-new-project-claude-code-skill.md
- **Context:** Initial task creation

### 2026-03-04T22:17:13Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-04T22:21:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
