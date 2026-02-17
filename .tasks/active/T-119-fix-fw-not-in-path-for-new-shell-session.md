---
id: T-119
name: Fix fw not in PATH for new shell sessions
description: >
  fw binary at bin/fw is not added to PATH by any shell profile or init script. Every new Bash tool call loses PATH, requiring manual export. Fix: context init should export PATH, or fw init should add to shell profile. Discovered during T-118 investigation — silent bypass of this error happened 3+ times.
status: started-work
workflow_type: build
owner: agent
tags: []
related_tasks: []
created: 2026-02-17T14:46:58Z
last_update: 2026-02-17T14:46:58Z
date_finished: null
---

# T-119: Fix fw not in PATH for new shell sessions

## Context

[Link to design docs, specs, or predecessor tasks]

## Updates

### 2026-02-17T14:46:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-119-fix-fw-not-in-path-for-new-shell-session.md
- **Context:** Initial task creation
