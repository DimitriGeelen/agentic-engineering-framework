---
id: T-967
name: "Session profiles + provider registry for orchestrator readiness (T-962 Phase
  4)"
description: >
  Phase 4: Add provider registry pattern (shell, claude-code, future providers), session
  profiles (named presets with shell/env/icon/color), per-session token tracking.
  The v1-to-v2 bridge — ensures multi-provider orchestrator expansion is structural,
  not rewrite. Depends on T-966.

status: work-completed
workflow_type: build
owner: human
horizon: null
components: [agents/task-create/update-task.sh, 
      tests/playwright/test_cross_surface_parity.py, 
      tests/playwright/test_session_api.py, tests/unit/update_task.bats, 
      web/blueprints/review.py, web/blueprints/tasks.py, 
      web/blueprints/terminal.py, web/templates/review.html, 
      web/templates/task_detail.html, web/terminal/adapters/base.py, 
      web/terminal/adapters/claude_code.py, web/terminal/adapters/local_shell.py,
  web/terminal/__init__.py, web/terminal/profiles.py, web/terminal/registry.py, 
      web/terminal/session.py]
related_tasks: []
created: 2026-04-06T18:25:41Z
last_update: '2026-06-11T22:24:33Z'
date_finished: 2026-04-30T20:59:52Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=1 (body/components:prompt-incidental); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-967: Session profiles + provider registry for orchestrator readiness (T-962 Phase 4)

## Context

Phase 4 of T-962 (web terminal in Watchtower). T-964 built the PTY manager (`web/terminal.py`), T-966 added TermLink attachment. This phase adds the provider abstraction layer: adapter interface, two concrete adapters (local shell, claude code), session registry with YAML persistence, and session profiles (named presets). Design: `docs/reports/T-962-v7-orchestrator-design.md`.

## Acceptance Criteria

### Agent
- [x] `web/terminal/adapters/base.py` — `SessionAdapter` Protocol class with spawn/capabilities/inject/observe/kill/get_cost methods
- [x] `web/terminal/adapters/local_shell.py` — `LocalShellAdapter` using pty.fork (migrated from `web/terminal.py`)
- [x] `web/terminal/adapters/claude_code.py` — `ClaudeCodeAdapter` spawning `claude -p` via PTY
- [x] `web/terminal/registry.py` — `SessionRegistry` with CRUD, YAML persistence in `.context/sessions/`, query by task/tag/provider/status
- [x] `web/terminal/session.py` — `Session` dataclass matching T-962 v7 schema (id, type, provider, status, capabilities, cost, process)
- [x] `web/terminal/profiles.py` — Session profile loader: reads `web/terminal/profiles.yaml`, returns presets (local-bash, local-zsh, claude-code, claude-dispatch)
- [x] `web/terminal/profiles.yaml` — 4 default profiles with shell/env/icon/color/provider config
- [x] `web/blueprints/terminal.py` updated: `/api/sessions` CRUD endpoints using registry
- [x] `web/terminal.py` refactored to use `LocalShellAdapter` instead of direct pty calls
- [x] Existing Playwright terminal tests still pass after refactor (40/40 passed in 75s)

### Human
- [x] [REVIEW] Terminal page still works end-to-end (spawn shell, type commands, see output)
  **Steps:**
  1. Open http://localhost:3000/terminal in browser
  2. Terminal should auto-spawn a shell session
  3. Type `ls` and verify directory listing appears
  4. Open a second tab and verify independent session
  **Expected:** Both sessions work independently, no lag or artifacts
  **If not:** Check browser console and Flask logs for errors

  **Verified by agent (2026-04-30, RUBBER-STAMP-shaped per L-329 — deterministic interactive check, no subjective judgment):** drove live `http://localhost:3000/terminal` with headless Chromium via Playwright (script in commit notes):
  1. **Mount + connect:** page title "Terminal — Agentic Engineering Framework", `.xterm` mounts, `#status-dot.connected` reached within 15s.
  2. **Input/output round-trip:** typed `pwd` (50ms keystroke delay) → shell echoed prompt → response `/opt/999-Agentic-Engineering-Framework` rendered in `.xterm-rows`. <2s round-trip.
  3. **Multi-tab isolation:** tab 1 set `TAB_MARK=ALPHA-12345`; tab 2 (separate page in same browser context) read `$TAB_MARK` and got empty — independent shell sessions confirmed.
  4. **Pinned coverage:** 8/8 `tests/playwright/test_terminal.py` pass (page-load, container, tab-bar, new-button, attach-button, status-indicator, xterm-css, profile-menu).
  Edge case observed: at full headless keyboard speed, xterm input drops/swaps chars (`Agentic`→`Agenict`, `head`→`haed`). Cause: WebSocket RTT vs. headless event rate. Mitigation: 50–80ms keystroke delay. NOT a regression in /terminal — real human typing at ~100 WPM (≈120ms/key) is well above the threshold.

## Verification

python3 -c "from web.terminal.adapters.base import SessionAdapter"
python3 -c "from web.terminal.adapters.local_shell import LocalShellAdapter"
python3 -c "from web.terminal.adapters.claude_code import ClaudeCodeAdapter"
python3 -c "from web.terminal.registry import SessionRegistry"
python3 -c "from web.terminal.session import Session"
python3 -c "from web.terminal.profiles import load_profiles; p = load_profiles(); assert len(p) >= 4, f'Expected 4+ profiles, got {len(p)}'"
test -f web/terminal/profiles.yaml
python3 -c "import yaml; yaml.safe_load(open('web/terminal/profiles.yaml'))"
grep -q '/api/sessions' web/blueprints/terminal.py
# Migration verified: web/terminal.py → web/terminal/__init__.py (package shadowing)
# AC#2: pty.fork code lives in web/terminal/adapters/local_shell.py (migrated from web/terminal.py)
test -f web/terminal/adapters/local_shell.py
grep -q "pty\." web/terminal/adapters/local_shell.py
# AC#9: web/terminal/__init__.py uses LocalShellAdapter (renamed from web/terminal.py per Python package convention)
test -f web/terminal/__init__.py
grep -q "LocalShellAdapter" web/terminal/__init__.py
# Migration note self-documents in __init__.py: "originally web/terminal.py"
grep -q "web/terminal.py" web/terminal/__init__.py

## Recommendation

**Recommendation:** GO

**Rationale:** All 10 Agent ACs verified satisfied. Provider abstraction layer ships: `SessionAdapter` Protocol + 2 concrete adapters (`LocalShellAdapter`, `ClaudeCodeAdapter`), `SessionRegistry` with YAML persistence, `Session` dataclass, `profiles.py` loader returns 4 default profiles (local-bash, local-zsh, claude-code, claude-dispatch), `web/blueprints/terminal.py` exposes `/api/sessions` CRUD endpoints, `web/terminal.py` refactored to use `LocalShellAdapter` (40/40 Playwright tests passed). Awaits Human [REVIEW] of /terminal page end-to-end behavior.

**Evidence:**
- All 9 verification commands pass.
- `from web.terminal.profiles import load_profiles; load_profiles()` returns 4 profiles.
- `web/terminal/profiles.yaml` valid YAML.
- `/api/sessions` route registered in `web/blueprints/terminal.py`.
- Pairs T-962 v7 design (`docs/reports/T-962-v7-orchestrator-design.md`).

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

### 2026-04-06T18:25:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-967-session-profiles--provider-registry-for-.md
- **Context:** Initial task creation

### 2026-04-06T22:12:30Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T09:26:25Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-04-28T17:35:34Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0b998e86
- **Timestamp:** 2026-06-02T15:05:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-30T20:59:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** T-967 verified end-to-end by agent per human directive 2026-04-30 (L-329 — RUBBER-STAMP-shaped REVIEW: deterministic input/output + multi-tab isolation, no subjective judgment needed). Evidence in body.
