---
id: T-967
name: "Session profiles + provider registry for orchestrator readiness (T-962 Phase 4)"
description: >
  Phase 4: Add provider registry pattern (shell, claude-code, future providers), session profiles (named presets with shell/env/icon/color), per-session token tracking. The v1-to-v2 bridge — ensures multi-provider orchestrator expansion is structural, not rewrite. Depends on T-966.

status: captured
workflow_type: build
owner: human
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-04-06T18:25:41Z
last_update: 2026-04-12T09:26:25Z
date_finished: null
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
- [ ] [REVIEW] Terminal page still works end-to-end (spawn shell, type commands, see output)
  **Steps:**
  1. Open http://localhost:3000/terminal in browser
  2. Terminal should auto-spawn a shell session
  3. Type `ls` and verify directory listing appears
  4. Open a second tab and verify independent session
  **Expected:** Both sessions work independently, no lag or artifacts
  **If not:** Check browser console and Flask logs for errors

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
