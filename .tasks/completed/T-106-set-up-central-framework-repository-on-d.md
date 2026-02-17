---
id: T-106
name: Set up central framework repository on dev server
description: >
  Set up the framework as a git remote on the dev server to enable: (1) New users can git clone the framework, (2) Projects reference the framework via local clone, (3) Framework updates can be pulled by any clone, (4) Learnings harvested from projects can be pushed back. STEPS: Create bare git repo on dev server. Push current framework (master + main branches, all tags). Document the workflow: clone -> add to PATH -> fw init project -> fw harvest back. Add setup instructions to FRAMEWORK.md or a new INSTALL.md. Consider: should fw have a self-install command (fw install /usr/local/bin)? For PATH: recommend export PATH=/path/to/framework/bin:PATH in shell profile, or symlink bin/fw to /usr/local/bin/fw. OWNER: Human (requires dev server access and infrastructure decisions). DEPENDS ON: T-101, T-102, T-103 should be done first — publish a clean framework, not one with known bugs. NOTE: The hub-and-spoke model (framework hub knows about all projects) is a future enhancement — for now just get the basic git remote + clone + PATH working.
status: work-completed
workflow_type: build
owner: agent
tags: [devops, git, distribution, dev-server]
related_tasks: []
created: 2026-02-17T08:54:25Z
last_update: 2026-02-17T09:45:39Z
date_finished: null
---

# T-106: Set up central framework repository on dev server

## Context

Prerequisites T-101 through T-103 completed in session S-2026-0217-1018.

## Updates

### 2026-02-17T09:42:00Z — work-completed [claude-code]
- **Action:** Created project on OneDev 13.1.5, pushed master + v1.0.0 tag, documented workflow
- **Output:**
  - OneDev project: https://onedev.docker.ring20.geelenandcompany.com/agentic-engineering-framework
  - Clone URL: https://onedev.docker.ring20.geelenandcompany.com/agentic-engineering-framework.git
  - Dedicated API token created: `agentic-framework` (ID 4, owner perms, no expiry)
  - Git remote `onedev` added to local repo with credential store
  - Installation section added to FRAMEWORK.md (clone, PATH, verify)
  - Setup wizard cheat sheet updated with framework source URL
- **Context:**
  - OneDev API auth: HTTP Basic Auth with `username:access_token` (Bearer NOT supported in v13.1.5)
  - JWT token user provided was NOT a OneDev access token — OneDev tokens are 40-char random strings
  - Existing tokens on account: ci-registry-token, ci-registry-full, Claude-Ring20

### 2026-02-17T08:54:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-106-set-up-central-framework-repository-on-d.md
- **Context:** Initial task creation
