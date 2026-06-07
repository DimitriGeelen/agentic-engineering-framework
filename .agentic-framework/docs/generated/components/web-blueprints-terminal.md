# terminal

> Flask blueprint providing the interactive web terminal API with session creation, I/O, resize, and profile-based configuration

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/terminal.py`

## What It Does

Singleton registry and adapter map (initialized on first use)

## Dependencies (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [local_shell](/docs/generated/web-terminal-adapters-local_shell) | calls | Terminal adapter that spawns local shell sessions via PTY fork for interactive shell access in the web terminal |
| [claude_code](/docs/generated/web-terminal-adapters-claude_code) | calls | Terminal adapter that spawns Claude Code agent sessions via PTY using claude -p (prompt) or claude -c (interactive) commands |
| [profiles](/docs/generated/web-terminal-profiles) | calls | Loads named session profile presets from profiles.yaml for the terminal session creation UI |
| [registry](/docs/generated/web-terminal-registry) | calls | Provides CRUD operations and YAML file persistence for terminal session records stored in .context/sessions/ |
| [session](/docs/generated/web-terminal-session) | calls | Provider-neutral dataclass defining the terminal session descriptor schema with metadata, capabilities, and process info |
| [terminal](/docs/generated/web-templates-terminal) | renders | Jinja2 template rendering the interactive web terminal UI with tabbed sessions, xterm.js integration, and session controls |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [test_api_termlink](/docs/generated/tests-playwright-test_api_termlink) | called_by | Playwright tests for TermLink sessions API (T-1025). |

## Related

### Tasks
- T-964: Watchtower single terminal — xterm.js + Flask-SocketIO PTY bridge (T-962 Phase 1)
- T-966: TermLink session observation in Watchtower terminal (T-962 Phase 3)
- T-967: Session profiles + provider registry for orchestrator readiness (T-962 Phase 4)

---
*Auto-generated from Component Fabric. Card: `web-blueprints-terminal.yaml`*
*Last verified: 2026-04-06*
