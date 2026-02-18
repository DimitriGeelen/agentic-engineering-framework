---
id: T-139
name: Build budget-gate.sh PreToolUse hook (hybrid budget enforcement)
description: >
  Build the PreToolUse budget-gate.sh hook that reads token usage and BLOCKS tool calls at critical threshold. Hybrid approach: keep PostToolUse checkpoint.sh as fallback. Deliverables: (1) agents/context/budget-gate.sh — PreToolUse hook, (2) .budget-status file protocol, (3) settings.json update to add PreToolUse hook, (4) deprecate .commit-counter from hooks. Design: docs/T-138-inception-findings.md. Decision: T-138 GO — hybrid.
status: started-work
workflow_type: build
horizon: now
owner: agent
tags: []
related_tasks: []
created: 2026-02-18T07:29:16Z
last_update: 2026-02-18T07:29:16Z
date_finished: null
---

# T-139: Build budget-gate.sh PreToolUse hook (hybrid budget enforcement)

## Context

Design: `docs/T-138-inception-findings.md` (inception GO — hybrid approach)
Predecessor: T-138 (inception), T-128 (circuit breaker — being deprecated)

Hybrid approach: PreToolUse budget-gate.sh as primary enforcement (BLOCKS at critical), keep PostToolUse checkpoint.sh as fallback (warns + auto-handover). Cron deferred to separate task.

## Acceptance Criteria

- [x] `agents/context/budget-gate.sh` exists and is executable
- [x] budget-gate.sh reads token usage and returns exit 2 at critical (>=150K)
- [x] budget-gate.sh allows git/handover commands even at critical level
- [x] budget-gate.sh writes `.budget-status` file with level and timestamp
- [x] budget-gate.sh completes in <100ms (PreToolUse must be fast)
- [x] Settings.json has PreToolUse hook for Write|Edit|Bash targeting budget-gate.sh
- [x] PostToolUse checkpoint.sh retained as fallback (not removed)
- [x] Commit counter removed from commit-msg and post-commit hook templates
- [x] CLAUDE.md updated with new budget enforcement docs

## Verification

# budget-gate.sh exists and is executable
test -x agents/context/budget-gate.sh
# budget-gate.sh has correct exit code logic
grep -q 'exit 2' agents/context/budget-gate.sh
# Settings has PreToolUse budget-gate entry
python3 -c "import json; d=json.load(open('.claude/settings.json')); hooks=[h for h in d['hooks']['PreToolUse'] if 'budget-gate' in h['hooks'][0]['command']]; assert len(hooks)==1, 'missing budget-gate hook'"
# PostToolUse checkpoint.sh still present (hybrid — kept as fallback)
python3 -c "import json; d=json.load(open('.claude/settings.json')); hooks=[h for h in d['hooks']['PostToolUse'] if 'checkpoint' in h['hooks'][0]['command']]; assert len(hooks)==1, 'checkpoint.sh fallback missing'"
# Commit counter removed from hook templates
test "$(grep -c 'commit-counter' agents/git/lib/hooks.sh)" -eq 0

## Updates

### 2026-02-18T07:29:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-139-build-budget-gatesh-pretooluse-hook-hybr.md
- **Context:** Initial task creation
