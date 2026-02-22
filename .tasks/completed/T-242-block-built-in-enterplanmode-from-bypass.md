---
id: T-242
name: "Block built-in EnterPlanMode from bypassing framework governance"
description: >
  Add multi-layer defense to prevent Claude Code's built-in EnterPlanMode from bypassing framework governance. Layer 1: CLAUDE.md prohibition. Layer 2: PreToolUse hook. Layer 3: Gap registration.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [C-009]
related_tasks: []
created: 2026-02-22T07:39:09Z
last_update: 2026-02-22T07:49:57Z
date_finished: 2026-02-22T07:48:40Z
---

# T-242: Block built-in EnterPlanMode from bypassing framework governance

## Context

Prevent Claude Code's built-in `EnterPlanMode` from bypassing framework governance.
Evidence from T-241: plan mode skipped session init, task creation, commit cadence, and check-ins.
Research documented in `docs/reports/T-242-plan-mode-governance-bypass.md`.
Related: `/plan` skill (`.claude/commands/plan.md`) is the governed alternative.

## Acceptance Criteria

### Agent
- [x] CLAUDE.md contains "Plan Mode Prohibition" section with explicit `EnterPlanMode` ban
- [x] `.claude/settings.json` has PreToolUse hook for `EnterPlanMode` matcher
- [x] `agents/context/block-plan-mode.sh` exists, is executable, exits with code 2
- [x] Gap G-014 registered in `gaps.yaml` tracking enforcement uncertainty
- [x] `fw doctor` passes (enforcement baseline updated)
- [x] All modified files parse correctly (JSON, YAML)

### Human
- [x] After session restart, verify PreToolUse hook fires for EnterPlanMode (update G-014 status)

## Verification

grep -q "EnterPlanMode" /opt/999-Agentic-Engineering-Framework/CLAUDE.md
grep -q "EnterPlanMode" /opt/999-Agentic-Engineering-Framework/.claude/settings.json
test -x /opt/999-Agentic-Engineering-Framework/agents/context/block-plan-mode.sh
python3 -c "import json; json.load(open('/opt/999-Agentic-Engineering-Framework/.claude/settings.json'))"
python3 -c "import yaml; yaml.safe_load(open('/opt/999-Agentic-Engineering-Framework/.context/project/gaps.yaml'))"
/opt/999-Agentic-Engineering-Framework/bin/fw doctor 2>&1 | grep -q "All checks passed"

## Decisions

### 2026-02-22 — Multi-layer defense strategy
- **Chose:** Three-layer approach: CLAUDE.md prohibition (agent discipline) + PreToolUse hook (structural) + gap registration (tracking)
- **Why:** Cannot confirm if PreToolUse fires for mode-transition tools until next session restart. Layered defense covers both cases.
- **Rejected:** Single-layer CLAUDE.md-only (insufficient — T-241 showed agent ignores CLAUDE.md under plan mode's override prompt); hook-only (might not fire for EnterPlanMode)

## Updates

### 2026-02-22T07:39:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-242-block-built-in-enterplanmode-from-bypass.md
- **Context:** Initial task creation

### 2026-02-22T07:48:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
