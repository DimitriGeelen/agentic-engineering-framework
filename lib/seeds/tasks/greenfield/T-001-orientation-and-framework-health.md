---
id: T-001
name: "Orientation: explore framework and verify health for __PROJECT_NAME__"
description: >
  Understand what the Agentic Engineering Framework provides: task system, context fabric,
  enforcement hooks, agents. Verify everything is properly installed.
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [onboarding]
components: []
related_tasks: []
created: __DATE__
last_update: __DATE__
date_finished: null
---

# T-001: Orientation — explore framework and verify health for __PROJECT_NAME__

## Context

First task for __PROJECT_NAME__. Read CLAUDE.md to understand the framework, verify installation, and prepare for project definition.

## Acceptance Criteria

### Agent
- [ ] Read CLAUDE.md — understand core principle, task system, enforcement tiers
- [ ] Run `fw doctor` — all checks pass
- [ ] Run `fw audit` — note current state
- [ ] Install git hooks: `fw git install-hooks`

## Verification

fw doctor
fw audit

## Updates

### __DATE__ — task-created [fw-init]
- **Action:** Auto-created by `fw init` (greenfield onboarding)
