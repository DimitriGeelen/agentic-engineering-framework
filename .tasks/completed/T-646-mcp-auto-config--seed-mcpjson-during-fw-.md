---
id: T-646
name: "MCP auto-config — seed .mcp.json during fw init and reconcile during fw upgrade"
description: >
  MCP auto-config — seed .mcp.json during fw init and reconcile during fw upgrade

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-27T13:33:54Z
last_update: 2026-04-06T22:29:19Z
date_finished: 2026-03-27T13:49:20Z
---

# T-646: MCP auto-config — seed .mcp.json during fw init and reconcile during fw upgrade

## Context

Consumer projects get `.claude/settings.json` (hooks) during `fw init` but no `.mcp.json` for MCP servers. context7 and playwright are recommended MCPs but only available if manually installed. Need to seed `.mcp.json` during init and reconcile during upgrade.

## Acceptance Criteria

### Agent
- [x] `lib/init.sh` `generate_claude_code_config()` creates `.mcp.json` with context7 + playwright
- [x] `lib/upgrade.sh` reconciles `.mcp.json` — adds missing servers, preserves custom ones
- [x] `fw doctor` checks for `.mcp.json` presence (WARN if missing)
- [x] `.mcp.json` uses project-root-relative location (no absolute paths)
- [x] Upstream copy in `.agentic-framework/lib/init.sh` also updated
- [x] Consumer project gets .mcp.json after fw init (reclassified from Human RUBBER-STAMP per T-954)

### Human

## Verification

grep -q 'mcp.json' lib/init.sh
grep -q 'mcp.json' lib/upgrade.sh
grep -q 'mcp.json' bin/fw
python3 -c "import json; d=json.load(open('.mcp.json')); assert 'context7' in d and 'playwright' in d"
bash -n lib/init.sh
bash -n lib/upgrade.sh
grep -q "mcp" lib/init.sh

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

### 2026-03-27T13:33:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-646-mcp-auto-config--seed-mcpjson-during-fw-.md
- **Context:** Initial task creation

### 2026-03-27T13:49:20Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-06T22:29:19Z — status-update [task-update-agent]
- **Change:** horizon: now → next
