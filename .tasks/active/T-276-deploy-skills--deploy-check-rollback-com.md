---
id: T-276
name: "Deploy skills — /deploy-check, /rollback commands"
description: >
  Create framework skills for deployment lifecycle. /deploy-check: pre-deployment validation (task gate, health, registry, routes). /rollback: explicit deployment recovery with history from .context/deployments/. Each skill enforces task prerequisites, presents numbered options, logs outcomes. Depends on T-275 (needs gated fw deploy and deployment records). See docs/reports/T-272-deploy-watchtower-ring20.md RQ-5.

status: started-work
workflow_type: build
owner: human
horizon: now
tags: [deployment, skills, governance]
components: [.claude/commands/deploy-check.md, .claude/commands/rollback.md, .context/deployments/]
related_tasks: [T-272, T-275, T-277]
created: 2026-02-25T08:09:50Z
last_update: 2026-02-25T10:44:17Z
date_finished: null
---

# T-276: Deploy skills — /deploy-check, /rollback commands

## Context

Create Claude Code skills (`.claude/commands/`) for deployment lifecycle, following the pattern established by `/start-work`, `/explore`, and `/plan`. Each skill wraps mechanical operations with governance enforcement (task gate, user confirmation, outcome logging).

**Research:** [docs/reports/T-272-deploy-watchtower-ring20.md](../../docs/reports/T-272-deploy-watchtower-ring20.md) (RQ-5: Skill Integration)
**Parent inception:** T-272 | **Depends on:** T-275 (needs gated fw deploy and deployment records) | **Unblocks:** T-277

### Skills to create

**`/deploy-check`** (`.claude/commands/deploy-check.md`)
- Validates deployment readiness before triggering CI/CD
- Steps: check active task, run `fw audit --section deployment`, check registry reachable, verify health endpoint, validate Traefik routes exist
- Returns: numbered pass/fail checklist with remediation steps
- Follows `/start-work` pattern: gate first, then proceed

**`/rollback`** (`.claude/commands/rollback.md`)
- Recovery from failed deployment
- Steps: read `.context/deployments/` for latest deployment, show version info, confirm with user, execute `docker service rollback`, verify health, log outcome
- Returns: rollback status with before/after versions
- Safety: requires user confirmation (Tier 0 action)

## Acceptance Criteria

### Agent
- [x] `.claude/commands/deploy-check.md` exists and follows skill format
- [x] `.claude/commands/rollback.md` exists and follows skill format
- [x] `/deploy-check` enforces active task prerequisite
- [x] `/deploy-check` calls `fw audit --section deployment`
- [x] `/rollback` reads deployment history from `.context/deployments/`
- [x] `/rollback` requires explicit user confirmation before executing
- [x] Both skills present numbered options (per Agent Behavioral Rules)
- [x] Both skills registered in `.claude/settings.json` if needed

### Human
- [ ] Skills produce clear, actionable output
- [ ] Rollback skill correctly identifies previous deployment version

## Verification

# Skill files exist
test -f .claude/commands/deploy-check.md
test -f .claude/commands/rollback.md

# Skills reference fw deploy
grep -q "fw deploy" .claude/commands/deploy-check.md
grep -q "fw audit" .claude/commands/deploy-check.md

# Rollback references deployment records
grep -q "deployments" .claude/commands/rollback.md

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-02-25T08:09:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-276-deploy-skills--deploy-check-rollback-com.md
- **Context:** Initial task creation

### 2026-02-25T10:44:17Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
