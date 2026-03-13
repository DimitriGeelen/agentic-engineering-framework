---
id: T-003
name: "Register key components of __PROJECT_NAME__ in fabric"
description: >
  Use fw fabric register to map the most important source files and their dependencies.
  This creates the structural topology map for impact analysis and onboarding.
status: captured
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

# T-003: Register key components of __PROJECT_NAME__ in fabric

## Context

The Component Fabric (`.fabric/`) maps source files and their dependencies. Register the 5-10 most important files so `fw fabric blast-radius` and `fw fabric deps` work for __PROJECT_NAME__.

## Acceptance Criteria

### Agent
- [ ] Identify 5-10 key source files (entry points, core modules, config)
- [ ] Register each with `fw fabric register <path>`
- [ ] Run `fw fabric overview` — shows registered components
- [ ] Run `fw fabric drift` — no critical drift

## Verification

# Fabric has registered components
test -d .fabric/components
test "$(ls .fabric/components/*.yaml 2>/dev/null | wc -l)" -ge "3"
