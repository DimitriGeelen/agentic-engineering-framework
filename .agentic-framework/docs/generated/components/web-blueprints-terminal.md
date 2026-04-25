# terminal

> Flask blueprint providing the interactive web terminal API with session creation, I/O, resize, and profile-based configuration

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/terminal.py`

## What It Does

Singleton registry and adapter map (initialized on first use)

## Dependencies (7)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | calls |
| `web/terminal/adapters/local_shell.py` | calls |
| `web/terminal/adapters/claude_code.py` | calls |
| `web/terminal/profiles.py` | calls |
| `web/terminal/registry.py` | calls |
| `web/terminal/session.py` | calls |
| `web/templates/terminal.html` | renders |

## Used By (3)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/__init__.py` | called_by |
| `web/blueprints/__init__.py` | registered_by |

## Related

### Tasks
- T-964: Watchtower single terminal — xterm.js + Flask-SocketIO PTY bridge (T-962 Phase 1)
- T-966: TermLink session observation in Watchtower terminal (T-962 Phase 3)

---
*Auto-generated from Component Fabric. Card: `web-blueprints-terminal.yaml`*
*Last verified: 2026-04-06*
