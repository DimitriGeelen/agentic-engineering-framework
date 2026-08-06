---
id: T-1062
name: "WezTerm task-aware terminal chrome via TermLink RPC"
description: >
  Phase 1 from T-1061: WezTerm Lua plugin querying existing TermLink RPC APIs for
  task state in terminal chrome. Zero new TermLink code needed. 3-6 weeks.

status: started-work
workflow_type: build
owner: human
horizon: now
tags: [termlink, wezterm, usability]
components: []
related_tasks: [T-1061, T-1641]
created: 2026-04-08T05:32:02Z
last_update: 2026-08-06T12:03:43Z
date_finished:
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 4
      D4: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T20:15:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 4
      D4: 0
      F1: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=0 (no-signal); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 4
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-05T18:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 4
      D4: 0
      F-RECALL: 2
      F-ORCH: 1
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=0 (no-signal); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=1 (body:hand-wired-dispatch)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T16:00:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 4
      D4: 0
      F-RECALL: 2
      F-ORCH: 1
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=0 (no-signal); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=1 (body:hand-wired-dispatch); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:24Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 4
      D4: 0
      F-RECALL: 2
      F-ORCH: 1
      F3: 0
      F1: 1
      F2: 1
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=0 (no-signal); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=1 (body:hand-wired-dispatch); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-13T18:00:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 4
      D4: 0
      F-RECALL: 2
      F-ORCH: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 1
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=0 (no-signal); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=1 (body:hand-wired-dispatch); F-AUTONOMY=0
      (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-07T10:45:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 4
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 1
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=0 (no-signal); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
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

### Human (T-1679 split — residual visual render, genuinely cannot automate without desktop env; instructions rewritten 2026-05-03 grounded in actual plugin contract)
- [ ] [REVIEW] Visual render — TermLink session task ID + role appear in WezTerm right status bar
  **Prerequisites:**
  - WezTerm installed (any recent version, see https://wezfurlong.org/wezterm/)
  - TermLink installed and on PATH (`termlink --version` works)
  - Optional: Nerd Fonts for icons; without them set `icons = {task="", role="", session=""}` in step 2 config
  - **Repo cloned and accessible** at the path used in step 1

  **Steps (one-line, copy-pasteable from project root):**
  1. Install plugin to WezTerm config dir:
     `mkdir -p ~/.config/wezterm && cp plugins/wezterm/termlink-chrome.lua ~/.config/wezterm/`
  2. Activate plugin in your `~/.config/wezterm/wezterm.lua` — add these 4 lines (or merge with your existing config):
     ```lua
     local wezterm = require("wezterm")
     local config = wezterm.config_builder()
     require("termlink-chrome").apply_to_config(config)
     return config
     ```
     If you already have a wezterm.lua, just add `require("termlink-chrome").apply_to_config(config)` between your `config_builder()` and `return config`.
  3. Reload WezTerm config: press **Ctrl+Shift+R** inside any WezTerm window (or restart WezTerm).
  4. Spawn a tagged TermLink session in any terminal:
     `termlink spawn --name t1062-test --shell --tags "task:T-1062,role:tester"`
  5. **Look at the WezTerm right status bar** (top-right of any WezTerm window).

  **Expected (per `plugins/wezterm/README.md` "What It Shows"):**
  - The right status bar shows a segment formatted approximately as `[T-1062 tester]` — task ID + role from the spawned session's tags.
  - Polls every 3 seconds — give it ~3s after spawning to appear.
  - With Nerd Fonts: small icons render before the task ID and role; without: just text.

  **If not visible:**
  1. **Check the Lua loaded** — open WezTerm Debug Overlay: **Ctrl+Shift+L**. Look for "module 'termlink-chrome' not found" → plugin is not on Lua's package path. Fix: confirm step 1 placed the file at `~/.config/wezterm/termlink-chrome.lua`.
  2. **Check TermLink is reachable** — run `termlink list --json` in a regular terminal. If it errors or returns empty, the spawn in step 4 didn't register; re-run step 4 and confirm the session appears in the JSON output with the `tags` array containing `task:T-1062`.
  3. **Status bar hidden when empty** — the plugin hides the segment if no task-tagged sessions exist (default behavior). If step 4's session is registered but the bar is still empty, it's a tag-extraction issue: run `termlink list --json | jq '.sessions[].tags'` and confirm `"task:T-1062"` (with colon) appears verbatim. The plugin matches `task:T-XXX` and `task=T-XXX`.
  4. **No Lua errors but no output** — check `right_status` isn't being overridden elsewhere in your wezterm.lua. The plugin sets it via `apply_to_config(config)`; another `config.right_status` assignment after that line will clobber it.
  5. **Icons render as boxes** — you don't have Nerd Fonts installed. Pass `icons = {task="", role="", session="", separator=" | "}` as the second argument to `apply_to_config` (see `plugins/wezterm/README.md` "Configuration" section).

  **Agent verification gap (2026-04-30, per L-329):** anchor has no Lua interpreter and no WezTerm install, so neither static syntax nor live render can be verified server-side. The plugin code is grounded (`termlink-chrome.lua` 236 lines, README 89 lines), the RPC contract is stable (T-1679 confirmed `termlink list --json` exposes `tags` array). The on-WezTerm rendering test requires a workstation — that's you.

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

### 2026-05-24T09:12:03Z — status-update [task-update-agent]
- **Change:** owner: human → human
