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

## For the Operator

**What is happening:** the agent picks 5-10 files that actually matter in __PROJECT_NAME__
— entry points, core modules, config — and registers each one in the **component fabric**.

**Why it matters to you:** the fabric is a map of what depends on what. Once it exists, the
agent can answer *what breaks if I change this file* before changing it, rather than
finding out afterwards. `fw fabric blast-radius` is the question it answers, and it is the
difference between a confident edit and a hopeful one.

This step only exists for projects that already have code — a greenfield project builds its
fabric as it builds its files. Which files get registered is a judgement call the agent is
making about *your* codebase, so it is worth a glance.

**What you can do meanwhile:** look at the list it chose. If it missed the module everything
actually routes through, tell it — the map is only as good as its coverage, and you know
this codebase better than it does right now.

**Go deeper:** Watchtower `/fabric` — the same map, clickable, with the dependency graph
rendered.

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
