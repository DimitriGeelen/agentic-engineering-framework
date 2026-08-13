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

## For the Operator

*Read this if you want to; nothing here is yours to do, and nothing here blocks the agent.*

**What is happening:** the agent is reading CLAUDE.md and running two health checks.
`fw doctor` asks *is this install wired correctly*. `fw audit` asks *is this project's
governance in good standing*. On a brand-new project audit reports warnings — that is
expected, it is measuring a history that does not exist yet.

**Why it matters to you:** the one rule everything else hangs off is **nothing gets done
without a task**. That is not a convention the agent has agreed to follow — it is a hook
that refuses file edits when no task is active. If you ever see the agent stop and say it
is blocked, this is usually why, and it is working as intended.

**What you can do meanwhile:** open Watchtower (`fw serve`, then the URL it prints). It is
the window into everything below — tasks, decisions, health, the maps named throughout
this curriculum.

**Go deeper:** `fw corpus explain aef-session-lifecycle` — what a session is, start to end.
Or `fw corpus explain aef-greenfield-onboarding` — see the full T-001→T-005 onboarding prologue as a workflow diagram.

## Acceptance Criteria

### Agent
- [ ] Read CLAUDE.md — understand core principle, task system, enforcement tiers
- [ ] Run `fw doctor` — all checks pass
- [ ] Run `fw audit` — note current state
- [ ] Install git hooks: `fw git install-hooks`

## Verification

fw doctor
# fw audit exits 1 for warnings (expected on fresh projects) — only block on exit 2 (failures)
fw audit; test $? -le 1

## Updates

### __DATE__ — task-created [fw-init]
- **Action:** Auto-created by `fw init` (greenfield onboarding)
