# registry

> Provides CRUD operations and YAML file persistence for terminal session records stored in .context/sessions/

**Type:** script | **Subsystem:** watchtower | **Location:** `web/terminal/registry.py`

## What It Does

In-memory cache of active sessions (pid/fd are not persisted across restarts)

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `web/terminal/session.py` | calls |

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/sessions.py` | called_by |
| `web/blueprints/terminal.py` | called_by |

---
*Auto-generated from Component Fabric. Card: `web-terminal-registry.yaml`*
*Last verified: 2026-04-06*
