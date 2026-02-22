---
id: T-247
name: "Dispatch fabric context + auto-registration — close agent blind spots"
description: >
  Two related fixes for agent blind spots: (1) Update dispatch preamble (agents/dispatch/preamble.md) to include fabric awareness guidance — sub-agents should run fw fabric deps before modifying registered components. Currently dispatch preamble has zero fabric references and cross-agent awareness scores 1/10. (2) Add auto-registration of new files in post-commit hook — when git diff shows files not matching any component card, run fw fabric scan on them (advisory, not blocking). Currently new files created during tasks don't get registered until manual fw fabric register. Research: docs/reports/T-235-agent-fabric-awareness-vector-db.md §Topic 1 Gaps 3-5. Also: /tmp/fw-agent-fabric-status.md §3.4 and §3.5. Related: T-236 (blast-radius in post-commit — done, extend same hook), T-244 (pre-edit awareness — companion task).

status: started-work
workflow_type: build
owner: agent
horizon: later
tags: [fabric, dispatch, auto-registration]
components: []
related_tasks: []
created: 2026-02-22T09:29:59Z
last_update: 2026-02-22T15:05:14Z
date_finished: null
---

# T-247: Dispatch fabric context + auto-registration — close agent blind spots

## Context

Closes T-235 Gap #3-5 (cross-agent fabric blindness). Two changes: (1) dispatch preamble now includes fabric awareness rules for sub-agents, (2) post-commit hook v1.5 detects new files without component cards and suggests registration.

## Acceptance Criteria

### Agent
- [x] Dispatch preamble includes fabric awareness section
- [x] Preamble instructs sub-agents to check deps before editing high-connectivity files
- [x] Post-commit hook detects new files without component cards (advisory)
- [x] Hook template in hooks.sh updated to v1.5 with auto-registration advisory
- [x] Installed hook (.git/hooks/post-commit) updated to match
- [x] Non-source files (*.md, *.yaml, .context/, docs/) excluded from registration check

## Verification

grep -q "Fabric Awareness" agents/dispatch/preamble.md
grep -q "auto-registration" agents/git/lib/hooks.sh
grep -q "VERSION=1.5" agents/git/lib/hooks.sh
grep -q "UNREG_COUNT" .git/hooks/post-commit

## Updates

### 2026-02-22T09:29:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-247-dispatch-fabric-context--auto-registrati.md
- **Context:** Initial task creation

### 2026-02-22T15:05:14Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
