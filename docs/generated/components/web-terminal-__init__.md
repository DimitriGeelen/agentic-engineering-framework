# __init__

> Package entry point that manages PTY processes and bridges them to Flask-SocketIO WebSocket connections for the web terminal

**Type:** script | **Subsystem:** watchtower | **Location:** `web/terminal/__init__.py`

## What It Does

Singleton adapter for backward compatibility

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [local_shell](/docs/generated/web-terminal-adapters-local_shell) | calls | Terminal adapter that spawns local shell sessions via PTY fork for interactive shell access in the web terminal |

## Related

### Tasks
- T-967: Session profiles + provider registry for orchestrator readiness (T-962 Phase 4)
- T-991: Fix web test failures — update monkeypatch paths after subprocess_utils refactor

---
*Auto-generated from Component Fabric. Card: `web-terminal-__init__.yaml`*
*Last verified: 2026-04-06*
