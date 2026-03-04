---
id: T-300
name: "Create README.md with quickstart guide"
description: >
  Framework repo has no README.md — zero entry point for humans. FRAMEWORK.md is agent-facing, not human-facing. Need: one-paragraph description, prerequisites (python3, git, bash), install (3 commands), bootstrap project (fw init, fw doctor), first task (fw work-on), links to FRAMEWORK.md and CLAUDE.md. Target: ~50-100 lines. Source: T-294 simulation O-001, new-user-perspective agent.

status: work-completed
workflow_type: build
owner: human
horizon: next
tags: []
components: []
related_tasks: [T-294]
created: 2026-03-04T16:16:05Z
last_update: 2026-03-04T18:25:31Z
date_finished: 2026-03-04T18:25:31Z
---

# T-300: Create README.md with quickstart guide

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] README.md exists at framework root
- [x] Contains prerequisites, install, quickstart, key commands
- [x] Links to FRAMEWORK.md and CLAUDE.md
- [x] Under 100 lines

### Human
- [ ] Content is clear and accurate for a new user

## Verification

test -f /opt/999-Agentic-Engineering-Framework/README.md
grep -q "fw work-on" /opt/999-Agentic-Engineering-Framework/README.md
grep -q "FRAMEWORK.md" /opt/999-Agentic-Engineering-Framework/README.md

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

### 2026-03-04T16:16:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-300-create-readmemd-with-quickstart-guide.md
- **Context:** Initial task creation

### 2026-03-04T18:22:32Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-04T18:25:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
