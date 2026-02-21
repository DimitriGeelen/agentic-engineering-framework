---
id: T-229
name: "Fix HIGH severity enforcement bypasses — B-001 (--no-verify) and B-005 (hook config)"
description: >
  Implement fixes for the two HIGH severity bypass vectors from T-228 analysis: (1) B-001: Detect --no-verify in check-tier0.sh as a Tier 0 destructive pattern. Also expand keyword pre-filter. (2) B-005: Detect Write/Edit to .claude/settings.json in check-tier0.sh or check-active-task.sh — require Tier 0 approval. Also add B-003 Tier 0 pattern gaps (find -delete, dd, chmod 000, mkfs, pkill).

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: [agents/context/check-tier0.sh, agents/context/check-active-task.sh]
related_tasks: [T-228]
created: 2026-02-21T14:19:45Z
last_update: 2026-02-21T14:19:45Z
date_finished: null
---

# T-229: Fix HIGH severity enforcement bypasses — B-001 (--no-verify) and B-005 (hook config)

## Context

Fixes for HIGH severity bypass vectors identified in T-228. See `docs/reports/T-228-enforcement-bypass-analysis.md`.

## Acceptance Criteria

### Agent
- [x] B-001: `--no-verify` detected as Tier 0 pattern in check-tier0.sh (both git commit and git push)
- [x] B-005: Write/Edit to `.claude/settings.json` blocked by check-active-task.sh (Tier 0 or explicit block)
- [x] B-003: Tier 0 patterns expanded with `find -delete`, `dd if=`, `chmod -R 000`, `mkfs`, `pkill -9`
- [x] Keyword pre-filter updated to match new patterns
- [x] Existing safe commands still pass through (no false positives on normal git operations)

## Verification

# B-001: --no-verify must be detected (exit 2 = blocked)
echo '{"tool_input":{"command":"git commit --no-verify -m test"}}' | /opt/999-Agentic-Engineering-Framework/agents/context/check-tier0.sh 2>/dev/null; test $? -eq 2
echo '{"tool_input":{"command":"git push --no-verify"}}' | /opt/999-Agentic-Engineering-Framework/agents/context/check-tier0.sh 2>/dev/null; test $? -eq 2
# B-003: find -delete must be detected
echo '{"tool_input":{"command":"find / -name *.log -delete"}}' | /opt/999-Agentic-Engineering-Framework/agents/context/check-tier0.sh 2>/dev/null; test $? -eq 2
# Safe commands must pass (exit 0 = allowed)
echo '{"tool_input":{"command":"git status"}}' | /opt/999-Agentic-Engineering-Framework/agents/context/check-tier0.sh 2>/dev/null; test $? -eq 0
echo '{"tool_input":{"command":"git commit -m \"T-229: test\""}}' | /opt/999-Agentic-Engineering-Framework/agents/context/check-tier0.sh 2>/dev/null; test $? -eq 0

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

### 2026-02-21T14:19:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-229-fix-high-severity-enforcement-bypasses--.md
- **Context:** Initial task creation
