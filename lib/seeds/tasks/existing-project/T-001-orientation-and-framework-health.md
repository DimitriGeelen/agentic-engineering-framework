---
id: T-001
name: "Orientation: understand __PROJECT_NAME__ and verify framework health"
description: >
  Read project files, understand the tech stack, and verify the framework is properly
  installed. This is the first task — it establishes context for all subsequent work.
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

# T-001: Orientation — understand __PROJECT_NAME__ and verify framework health

## Context

First task after `fw init`. Read existing project files, understand what __PROJECT_NAME__ does, and verify the framework is healthy.

## Acceptance Criteria

### Agent
- [ ] Read README and understand project purpose, tech stack, entry points
- [ ] Run `fw doctor` — all checks pass
- [ ] Run `fw audit` — note current pass/warn/fail counts as baseline
- [ ] Install git hooks: `fw git install-hooks`

## Verification

fw doctor
fw audit

## Updates

### __DATE__ — task-created [fw-init]
- **Action:** Auto-created by `fw init` (existing-project onboarding)
