# base

> SessionAdapter protocol — defines the interface for terminal session backends (local shell, Claude Code). Used by terminal blueprint.

**Type:** protocol | **Subsystem:** watchtower | **Location:** `web/terminal/adapters/base.py`

**Tags:** `protocol`, `terminal`, `adapter`

## What It Does

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [local_shell](/docs/generated/web-terminal-adapters-local_shell) | implements | Terminal adapter that spawns local shell sessions via PTY fork for interactive shell access in the web terminal |
| [claude_code](/docs/generated/web-terminal-adapters-claude_code) | implements | Terminal adapter that spawns Claude Code agent sessions via PTY using claude -p (prompt) or claude -c (interactive) commands |
| [terminal](/docs/generated/web-blueprints-terminal) | called_by | Flask blueprint providing the interactive web terminal API with session creation, I/O, resize, and profile-based configuration |

## Related

### Tasks
- T-967: Session profiles + provider registry for orchestrator readiness (T-962 Phase 4)

---
*Auto-generated from Component Fabric. Card: `web-terminal-adapters-base.yaml`*
*Last verified: 2026-04-06*
