---
id: T-681
name: "Add TermLink MCP server to fw init default MCP config"
description: >
  F-5: fw init seeds .mcp.json with context7 and playwright but not TermLink. TermLink MCP is the primary tool for cross-project isolation (Path C). Add termlink mcp serve to default MCP config during init. Discovered during T-679.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/init.sh, lib/upgrade.sh]
related_tasks: []
created: 2026-03-28T21:37:36Z
last_update: 2026-03-28T22:38:28Z
date_finished: 2026-03-28T22:38:28Z
---

# T-681: Add TermLink MCP server to fw init default MCP config

## Context

`fw init` seeds `.mcp.json` with context7 and playwright but not TermLink. TermLink MCP (`termlink mcp serve`) is the primary tool for cross-project isolation (Path C). Add it to the default config in init and the upgrade reconciliation path.

## Acceptance Criteria

### Agent
- [x] `init.sh` seeds `.mcp.json` with termlink MCP entry using bare `termlink` (PATH-based)
- [x] `upgrade.sh` recommended_servers includes termlink
- [x] `upgrade.sh` defaults dict includes termlink config
- [x] `upgrade.sh` create-from-scratch MCP JSON includes termlink
- [x] Existing projects get termlink added on `fw upgrade` (reconciliation)

## Verification

# init.sh has termlink in the seed MCP JSON
grep -q "termlink" lib/init.sh
# upgrade.sh has termlink in recommended servers
grep -q "termlink" lib/upgrade.sh

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

### 2026-03-28T21:37:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-681-add-termlink-mcp-server-to-fw-init-defau.md
- **Context:** Initial task creation

### 2026-03-28T22:36:58Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-28T22:38:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
