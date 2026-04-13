---
id: T-1062
name: "WezTerm task-aware terminal chrome via TermLink RPC"
description: >
  Phase 1 from T-1061: WezTerm Lua plugin querying existing TermLink RPC APIs for task state in terminal chrome. Zero new TermLink code needed. 3-6 weeks.

status: captured
workflow_type: build
owner: human
horizon: now
tags: [termlink, wezterm, usability]
components: []
related_tasks: [T-1061]
created: 2026-04-08T05:32:02Z
last_update: 2026-04-13T10:36:13Z
date_finished: null
---

# T-1062: WezTerm task-aware terminal chrome via TermLink RPC

## Context

Phase 1 from T-1061 inception (GO). WezTerm Lua plugin that queries existing TermLink RPC APIs to display task-aware metadata in the terminal chrome. Zero new TermLink code needed — reads session metadata (tags, roles, status, KV store) via `termlink list --json` and `termlink status`. Research: `docs/reports/T-1061-termlink-governance-substrate.md`.

**Repo:** Framework (plugin code lives here, no TermLink changes)

## Acceptance Criteria

### Agent
- [x] WezTerm Lua plugin file created at `plugins/wezterm/termlink-chrome.lua`
- [x] Plugin queries `termlink list --json` for active sessions
- [x] Plugin displays task ID and status from session tags in WezTerm tab/status bar
- [x] Plugin handles no-sessions gracefully (TermLink not running)
- [x] README in `plugins/wezterm/` with install instructions
- [x] Plugin registered in component fabric

### Human
- [ ] [REVIEW] Terminal chrome displays task state correctly when TermLink sessions are active
  **Steps:**
  1. Install plugin: `cp plugins/wezterm/termlink-chrome.lua ~/.config/wezterm/`
  2. Add `require("termlink-chrome")` to `~/.wezterm.lua`
  3. Start a TermLink session: `termlink spawn --name test --shell --tags "task:T-1062"`
  4. Verify task info appears in WezTerm status bar
  **Expected:** Task ID and status visible in terminal chrome
  **If not:** Check WezTerm debug overlay (Ctrl+Shift+L) for Lua errors

## Verification

termlink list --json > /dev/null 2>&1 || echo "SKIP: TermLink not running"
test -f plugins/wezterm/termlink-chrome.lua
test -f plugins/wezterm/README.md
grep -q "termlink" plugins/wezterm/termlink-chrome.lua

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

### 2026-04-08T05:32:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1062-wezterm-task-aware-terminal-chrome-via-t.md
- **Context:** Initial task creation

### 2026-04-08T05:46:01Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-13T06:25:19Z — status-update [task-update-agent]
- **Change:** horizon: next → now

### 2026-04-13T08:01:20Z — status-update [task-update-agent]
- **Change:** horizon: now → now

### 2026-04-13T10:36:13Z — status-update [task-update-agent]
- **Change:** horizon: now → now
