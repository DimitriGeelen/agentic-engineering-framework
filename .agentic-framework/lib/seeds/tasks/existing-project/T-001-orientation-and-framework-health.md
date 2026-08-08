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

## For the Operator

*Read this if you want to; nothing here is yours to do, and nothing here blocks the agent.*

**What is happening:** the agent is learning __PROJECT_NAME__ — reading the README, finding
the entry points — and running two health checks. `fw doctor` asks *is this install wired
correctly*. `fw audit` asks *is this project's governance in good standing*.

**Why it matters to you:** this is an existing codebase, so the audit numbers the agent
records now are a **baseline**, not a verdict. Warnings on first run are normal — the
framework has just arrived and is measuring a project that predates it. What matters is the
direction that number moves over the coming weeks.

The rule everything else hangs off: **nothing gets done without a task.** That is a hook
that refuses file edits when no task is active, not a habit the agent has agreed to. When
you see the agent stop and report itself blocked, this is usually why, and it is correct.

**What you can do meanwhile:** open Watchtower (`fw serve`, then the URL it prints) — the
window into tasks, decisions, health, and the maps named through this curriculum.

**Go deeper:** `fw corpus explain aef-session-lifecycle` — what a session is, start to end.

## Acceptance Criteria

### Agent
- [ ] Read README and understand project purpose, tech stack, entry points
- [ ] Run `fw doctor` — all checks pass
- [ ] Run `fw audit` — note current pass/warn/fail counts as baseline
- [ ] Install git hooks: `fw git install-hooks`

## Verification

fw doctor
# fw audit exits 1 for warnings (expected on fresh projects) — only block on exit 2 (failures)
fw audit; test $? -le 1

## Updates

### __DATE__ — task-created [fw-init]
- **Action:** Auto-created by `fw init` (existing-project onboarding)
