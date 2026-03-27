---
id: T-646
name: "MCP auto-config — seed .mcp.json during fw init and reconcile during fw upgrade"
description: >
  MCP auto-config — seed .mcp.json during fw init and reconcile during fw upgrade

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-27T13:33:54Z
last_update: 2026-03-27T13:33:54Z
date_finished: null
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

### Human
- [ ] [RUBBER-STAMP] Consumer project gets .mcp.json after fw init
  **Steps:**
  1. `cd /tmp && mkdir mcp-test && cd mcp-test && git init`
  2. `cd /tmp/mcp-test && /opt/999-Agentic-Engineering-Framework/bin/fw init --name mcp-test --no-first-run`
  3. `cat /tmp/mcp-test/.mcp.json`
  4. `rm -rf /tmp/mcp-test`
  **Expected:** .mcp.json exists with context7 and playwright entries
  **If not:** Check fw init output for errors

## Verification

grep -q 'mcp.json' lib/init.sh
grep -q 'mcp.json' lib/upgrade.sh
grep -q 'mcp.json' bin/fw
python3 -c "import json; d=json.load(open('.mcp.json')); assert 'context7' in d and 'playwright' in d"
bash -n lib/init.sh
bash -n lib/upgrade.sh

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
