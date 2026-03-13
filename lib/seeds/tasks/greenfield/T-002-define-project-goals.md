---
id: T-002
name: "Define goals and architecture for __PROJECT_NAME__"
description: >
  Inception task: define what __PROJECT_NAME__ will do, its constraints, and initial
  architecture. This is the foundational decision — everything else follows from here.
status: captured
workflow_type: inception
owner: human
horizon: now
tags: [onboarding, inception]
components: []
related_tasks: []
created: __DATE__
last_update: __DATE__
date_finished: null
---

# T-002: Define goals and architecture for __PROJECT_NAME__

## Context

This is an inception task. Define the problem __PROJECT_NAME__ solves, its goals, constraints, and initial architecture. Create a research artifact in `docs/reports/T-002-*.md` to capture findings.

## Acceptance Criteria

### Human
- [ ] [REVIEW] Problem statement is clear and scoped
  **Steps:**
  1. Read `docs/reports/T-002-*.md`
  2. Check: does it explain WHAT __PROJECT_NAME__ does and WHY?
  **Expected:** Clear problem statement, target users, key constraints
  **If not:** Add missing context to the research artifact

### Agent
- [ ] Research artifact exists: `docs/reports/T-002-*.md`
- [ ] Problem statement documented
- [ ] Go/no-go decision recorded: `fw inception decide T-002 go --rationale "..."`

## Verification

# Research artifact exists
ls docs/reports/T-002-*.md
