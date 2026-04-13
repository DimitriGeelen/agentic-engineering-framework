# __init__

> Package entry point that manages PTY processes and bridges them to Flask-SocketIO WebSocket connections for the web terminal

**Type:** script | **Subsystem:** watchtower | **Location:** `web/terminal/__init__.py`

## What It Does

Singleton adapter for backward compatibility

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `web/terminal/adapters/local_shell.py` | calls |

## Related

### Tasks
- T-991: Fix web test failures — update monkeypatch paths after subprocess_utils refactor

---
*Auto-generated from Component Fabric. Card: `web-terminal-__init__.yaml`*
*Last verified: 2026-04-06*
