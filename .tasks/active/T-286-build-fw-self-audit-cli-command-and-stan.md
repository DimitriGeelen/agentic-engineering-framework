---
id: T-286
name: "Build fw self-audit CLI command and standalone script"
description: >
  Build agents/audit/self-audit.sh as a standalone script that runs mechanical checks (Layers 1-4, syntax, directories) without needing Claude Code. Wire it into bin/fw as 'fw self-audit'. The script reads docs/prompts/framework-self-audit.md for the check specifications but executes them mechanically. Produces a structured report. Does NOT depend on fw itself (solves the chicken-and-egg problem). Follow-up to T-285 which created the prompt file.

status: started-work
workflow_type: build
owner: human
horizon: next
tags: [audit, deployment, cli]
components: []
related_tasks: []
created: 2026-03-01T09:37:55Z
last_update: 2026-03-01T10:14:07Z
date_finished: null
---

# T-286: Build fw self-audit CLI command and standalone script

## Context

Follow-up to T-285. Build a standalone script that mechanically checks Layers 1-4 from `docs/prompts/framework-self-audit.md`. Key constraint: no `fw` dependency (chicken-and-egg problem).

## Acceptance Criteria

### Agent
- [x] `agents/audit/self-audit.sh` exists and is executable
- [x] Script runs without depending on `fw` CLI (finds own root via script location)
- [x] Checks Layer 1: Foundation (bin/fw, CLAUDE.md, FRAMEWORK.md, agents, lib, hook scripts)
- [x] Checks Layer 2: Directories (.tasks/, .context/, .fabric/)
- [x] Checks Layer 3: Claude Code hooks (settings.json structure validation)
- [x] Checks Layer 4: Git hooks (commit-msg, post-commit, pre-push)
- [x] Produces structured PASS/WARN/FAIL output with summary counts
- [x] Exit code: 0=pass, 1=warnings, 2=failures
- [x] `fw self-audit` routes to `agents/audit/self-audit.sh`

### Human
- [ ] Test from a fresh project clone to verify standalone operation

## Verification

bash -n agents/audit/self-audit.sh
test -x agents/audit/self-audit.sh
agents/audit/self-audit.sh 2>&1 | grep -q "SUMMARY"
agents/audit/self-audit.sh 2>&1 | grep -q "PASS"
grep -q "self-audit" bin/fw

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

### 2026-03-01T09:37:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-286-build-fw-self-audit-cli-command-and-stan.md
- **Context:** Initial task creation

### 2026-03-01T10:07:37Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
