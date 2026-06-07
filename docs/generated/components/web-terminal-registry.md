# registry

> Provides CRUD operations and YAML file persistence for terminal session records stored in .context/sessions/

**Type:** script | **Subsystem:** watchtower | **Location:** `web/terminal/registry.py`

## What It Does

In-memory cache of active sessions (pid/fd are not persisted across restarts)

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [session](/docs/generated/web-terminal-session) | calls | Provider-neutral dataclass defining the terminal session descriptor schema with metadata, capabilities, and process info |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [sessions](/docs/generated/web-blueprints-sessions) | called_by | Flask blueprint that renders the terminal session management page listing active and historical sessions |
| [terminal](/docs/generated/web-blueprints-terminal) | called_by | Flask blueprint providing the interactive web terminal API with session creation, I/O, resize, and profile-based configuration |

## Related

### Tasks
- T-967: Session profiles + provider registry for orchestrator readiness (T-962 Phase 4)

---
*Auto-generated from Component Fabric. Card: `web-terminal-registry.yaml`*
*Last verified: 2026-04-06*
