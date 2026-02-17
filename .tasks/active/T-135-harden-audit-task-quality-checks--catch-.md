---
id: T-135
name: Harden audit task quality checks — catch thin/stub tasks
description: >
  Audit passes tasks with no acceptance criteria, no verification section, placeholder context, and descriptions that just say 'see plan Task X'. Add checks: (1) AC section exists with >=1 checkbox, (2) Verification section exists, (3) Context is not template placeholder, (4) Description is self-contained. Discovered in T-124 cycle 2: sprechloop agent created 11 stub tasks that all passed audit.
status: started-work
workflow_type: build
horizon: now
owner: human
tags: []
related_tasks: []
created: 2026-02-17T23:39:34Z
last_update: 2026-02-17T23:39:34Z
date_finished: null
---

# T-135: Harden audit task quality checks — catch thin/stub tasks

## Context

[Link to design docs, specs, or predecessor tasks]

## Updates

### 2026-02-17T23:39:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-135-harden-audit-task-quality-checks--catch-.md
- **Context:** Initial task creation
