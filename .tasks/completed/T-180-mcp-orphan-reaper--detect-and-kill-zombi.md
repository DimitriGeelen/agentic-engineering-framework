---
id: T-180
name: "MCP orphan reaper — detect and kill zombie MCP processes"
description: >
  When Claude Code sessions crash or end, MCP server processes (playwright-mcp, context7-mcp) become orphaned (PPID=1), accumulating ~50-80MB each. Evidence: 12 orphans found consuming ~600MB (sprechloop session 2026-02-18). Research complete: docs/reports/experiment-zombie-mcp-orphan-reaper.md covers detection (PGID-leader-alive check), cleanup approaches, safety, implementation sketch. Source brief: /opt/001-sprechloop/.context/briefs/framework-zombie-mcp-cleanup.md. Deliverables: (1) reap script in framework repo, (2) fw doctor warns about orphans, (3) crontab integration via fw init.

status: work-completed
workflow_type: build
owner: claude-code
horizon: next
tags: []
related_tasks: []
created: 2026-02-18T20:06:33Z
last_update: 2026-02-19T07:47:18Z
date_finished: 2026-02-19T07:47:18Z
---

# T-180: MCP orphan reaper — detect and kill zombie MCP processes

## Context

Research complete: docs/reports/experiment-zombie-mcp-orphan-reaper.md. Three deliverables.

## Acceptance Criteria

- [x] `agents/mcp/mcp-reaper.sh` script exists with --dry-run, --force, --age, --quiet flags
- [x] `fw mcp reap` command routes to the reaper script
- [x] `fw doctor` checks for orphaned MCP processes and warns
- [x] Script syntax validates (bash -n)

## Verification

test -x /opt/999-Agentic-Engineering-Framework/agents/mcp/mcp-reaper.sh
bash -n /opt/999-Agentic-Engineering-Framework/agents/mcp/mcp-reaper.sh
grep -q "mcp" /opt/999-Agentic-Engineering-Framework/bin/fw

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

### 2026-02-18T20:06:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-180-mcp-orphan-reaper--detect-and-kill-zombi.md
- **Context:** Initial task creation

### 2026-02-19T07:30:36Z — status-update [task-update-agent]
- **Change:** horizon: later → next

### 2026-02-19T07:43:58Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-19T07:47:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
