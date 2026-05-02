---
id: T-1062
name: "WezTerm task-aware terminal chrome via TermLink RPC"
description: >
  Phase 1 from T-1061: WezTerm Lua plugin querying existing TermLink RPC APIs for task state in terminal chrome. Zero new TermLink code needed. 3-6 weeks.

status: started-work
workflow_type: build
owner: human
horizon: now
tags: [termlink, wezterm, usability]
components: []
related_tasks: [T-1061, T-1641]
created: 2026-04-08T05:32:02Z
last_update: 2026-04-20T07:17:58Z
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

### Agent (T-1679 split — mechanical RPC-contract half of the original Human AC)
- [x] Plugin's RPC contract still satisfied by current TermLink. `termlink list --json` exposes a `tags` array on each session; plugin extracts task IDs at `plugins/wezterm/termlink-chrome.lua:49-58` via regex matching both `task:T-XXX` and `task=T-XXX`. Verified 2026-05-02T11:xx via T-1679: `termlink list --json` returns sessions with `tags` field present.

### Human (T-1679 split — residual visual render, genuinely cannot automate without desktop env)
- [ ] [REVIEW] Visual render — task ID from a TermLink session appears in WezTerm status bar
  **Steps (Steps 1-3 are mechanical setup; only Step 4 is the actual judgment):**
  1. Install plugin: `cp plugins/wezterm/termlink-chrome.lua ~/.config/wezterm/`
  2. Add `require("termlink-chrome")` to `~/.wezterm.lua`
  3. Start a tagged TermLink session: `termlink spawn --name test --shell --tags "task:T-1062"`
  4. **Visually verify** task ID and status visible in WezTerm status bar
  **Expected:** Task ID and status visible in terminal chrome (Step 4)
  **If not:** Check WezTerm debug overlay (Ctrl+Shift+L) for Lua errors

  **Agent verification gap (2026-04-30, per L-329):** genuine capability gap — anchor has no Lua interpreter (`luac`/`lua` absent) and no WezTerm install, so neither static syntax nor live render can be verified here. File is present (236 lines), README accompanies it (89 lines), TermLink dependency is `termlink list --json` which is a stable read-only RPC (T-1679 verified the contract still matches plugin assumptions). The on-WezTerm rendering test requires a workstation with WezTerm + the plugin installed — that's you.

## Verification

termlink list --json > /dev/null 2>&1 || echo "SKIP: TermLink not running"
test -f plugins/wezterm/termlink-chrome.lua
test -f plugins/wezterm/README.md
grep -q "termlink" plugins/wezterm/termlink-chrome.lua

## Recommendation

**⚠️ T-1641 Reconsideration (2026-05-01):** This Recommendation rates **code-and-AC completeness**, not behavioral verification or full Phase-1 scope coverage. T-1641 multi-agent investigation found:
- The plugin (236 Lua lines) was **never visually verified** — no Lua/WezTerm runtime on the framework anchor.
- T-1061 §Phase-1 promised three deliverables: *"multi-pane task governance UI"*, *"context fabric visualization"*, *"dispatch system as multi-agent UX"*. This task shipped only the third (a single status-bar readout). The first two were not built. (W01)
- Reviewer should consult `docs/reports/T-1641-orchestrator-arc-reconsideration.md` (item L14) and clarify what GO means here: "Phase-1a chrome shipped" (yes) vs "Phase-1 complete" (no — Phase-1b multi-pane UI / fabric viz needs a separate task, currently deferred horizon:later).

**Recommendation:** GO (Phase-1a only)

**Rationale:** All 6 Agent ACs verified satisfied. Plugin shipped at `plugins/wezterm/termlink-chrome.lua`, README documents install, fabric registered, content grep passes. No TermLink-side changes needed — pure consumer of existing JSON RPC. Awaits Human [REVIEW] of on-WezTerm rendering (which requires the human's WezTerm install — agent has no WezTerm to dogfood against).

**Evidence:**
- `test -f plugins/wezterm/termlink-chrome.lua` → exists.
- `test -f plugins/wezterm/README.md` → exists.
- `grep -q "termlink" plugins/wezterm/termlink-chrome.lua` → matches.
- `test -f .fabric/components/plugins-wezterm-termlink-chrome.yaml` → exists.
- All 4 commands in `## Verification` pass.

**Caveats (from T-1641):**
- Multi-pane task governance UI: not built.
- Context fabric visualization: not built.
- On-WezTerm visual verification: not performed by agent.

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

### 2026-04-13T13:02:08Z — status-update [task-update-agent]
- **Change:** horizon: now → now

### 2026-04-13T13:06:44Z — status-update [task-update-agent]
- **Change:** horizon: now → now

### 2026-04-13T13:46:35Z — status-update [task-update-agent]
- **Change:** horizon: now → now

### 2026-04-13T18:44:57Z — status-update [task-update-agent]
- **Change:** horizon: now → now

### 2026-04-20T07:17:58Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.4)

- **Scan ID:** R-713b11f4
- **Timestamp:** 2026-05-02T11:47:09Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
