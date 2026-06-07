# local_shell

> Terminal adapter that spawns local shell sessions via PTY fork for interactive shell access in the web terminal

**Type:** script | **Subsystem:** watchtower | **Location:** `web/terminal/adapters/local_shell.py`

## What It Does

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [terminal](/docs/generated/web-blueprints-terminal) | called_by | Flask blueprint providing the interactive web terminal API with session creation, I/O, resize, and profile-based configuration |
| [__init__](/docs/generated/web-terminal-__init__) | called_by | Package entry point that manages PTY processes and bridges them to Flask-SocketIO WebSocket connections for the web terminal |

## Related

### Tasks
- T-967: Session profiles + provider registry for orchestrator readiness (T-962 Phase 4)

---
*Auto-generated from Component Fabric. Card: `web-terminal-adapters-local_shell.yaml`*
*Last verified: 2026-04-06*
