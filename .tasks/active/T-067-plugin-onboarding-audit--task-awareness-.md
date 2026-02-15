---
id: T-067
name: Plugin onboarding audit — task-awareness check for new plugins
description: >
  When new Claude Code plugins are enabled, there is no process to check whether they are task-aware or whether their workflows conflict with the framework's core principle. Create a plugin onboarding checklist/script that: (1) scans new plugin skill files for task-system references, (2) flags TASK-SILENT and TASK-BYPASSING skills, (3) recommends integration wrappers or CLAUDE.md amendments, (4) optionally auto-generates a compatibility report. Predecessor: T-061 investigation. Should run whenever a plugin is added to settings.json.
status: captured
workflow_type: specification
owner: human
created: 2026-02-15T08:35:49Z
last_update: 2026-02-15T08:35:49Z
date_finished: null
---

# T-067: Plugin onboarding audit — task-awareness check for new plugins

## Context

[Link to design docs, specs, or predecessor tasks]

## Updates

### 2026-02-15T08:35:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-067-plugin-onboarding-audit--task-awareness-.md
- **Context:** Initial task creation
