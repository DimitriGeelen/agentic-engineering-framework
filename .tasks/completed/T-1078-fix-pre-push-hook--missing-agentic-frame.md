---
id: T-1078
name: "Fix pre-push hook — missing .agentic-framework audit path for consumer projects"
description: >
  Fix pre-push hook — missing .agentic-framework audit path for consumer projects

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-09T21:24:47Z
last_update: 2026-04-09T21:30:54Z
date_finished: 2026-04-09T21:30:54Z
---

# T-1078: Fix pre-push hook — missing .agentic-framework audit path for consumer projects

## Context

Pre-push hook template in `agents/git/lib/hooks.sh` checks `framework_path` (removed T-498) and `agents/audit/audit.sh` (framework repo only), but never `.agentic-framework/agents/audit/audit.sh` — the actual location in consumer projects. Discovered in 025-WokrshopDesigner where push was blocked with "ERROR: Audit script not found".

## Acceptance Criteria

### Agent
- [x] Pre-push hook template checks `.agentic-framework/agents/audit/audit.sh` path
- [x] Error message lists all 3 checked paths
- [x] Existing pre-push tests pass (no dedicated pre-push tests exist; hook template is embedded)
- [x] Consumer project hook reinstall works via `fw upgrade` (upgrade.sh:308 calls install-hooks)

## Verification

grep -q '.agentic-framework/agents/audit/audit.sh' agents/git/lib/hooks.sh
grep -q '.agentic-framework' agents/git/lib/hooks.sh

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

### 2026-04-09T21:24:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1078-fix-pre-push-hook--missing-agentic-frame.md
- **Context:** Initial task creation

### 2026-04-09T21:30:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
