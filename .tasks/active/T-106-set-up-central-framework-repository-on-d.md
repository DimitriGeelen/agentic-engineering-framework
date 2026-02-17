---
id: T-106
name: Set up central framework repository on dev server
description: >
  Set up the framework as a git remote on the dev server to enable: (1) New users can git clone the framework, (2) Projects reference the framework via local clone, (3) Framework updates can be pulled by any clone, (4) Learnings harvested from projects can be pushed back. STEPS: Create bare git repo on dev server. Push current framework (master + main branches, all tags). Document the workflow: clone -> add to PATH -> fw init project -> fw harvest back. Add setup instructions to FRAMEWORK.md or a new INSTALL.md. Consider: should fw have a self-install command (fw install /usr/local/bin)? For PATH: recommend export PATH=/path/to/framework/bin:PATH in shell profile, or symlink bin/fw to /usr/local/bin/fw. OWNER: Human (requires dev server access and infrastructure decisions). DEPENDS ON: T-101, T-102, T-103 should be done first — publish a clean framework, not one with known bugs. NOTE: The hub-and-spoke model (framework hub knows about all projects) is a future enhancement — for now just get the basic git remote + clone + PATH working.
status: captured
workflow_type: build
owner: human
tags: [devops, git, distribution, dev-server]
related_tasks: []
created: 2026-02-17T08:54:25Z
last_update: 2026-02-17T08:54:25Z
date_finished: null
---

# T-106: Set up central framework repository on dev server

## Context

[Link to design docs, specs, or predecessor tasks]

## Updates

### 2026-02-17T08:54:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-106-set-up-central-framework-repository-on-d.md
- **Context:** Initial task creation
