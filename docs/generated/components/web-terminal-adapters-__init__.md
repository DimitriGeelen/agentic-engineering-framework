# __init__

> TODO: describe what this component does

**Type:** script | **Subsystem:** watchtower | **Location:** `web/terminal/adapters/__init__.py`

## What It Does

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [local_shell](/docs/generated/web-terminal-adapters-local_shell) | calls | Terminal adapter that spawns local shell sessions via PTY fork for interactive shell access in the web terminal |
| [claude_code](/docs/generated/web-terminal-adapters-claude_code) | calls | Terminal adapter that spawns Claude Code agent sessions via PTY using claude -p (prompt) or claude -c (interactive) commands |
| [local_shell](/docs/generated/web-terminal-adapters-local_shell) | uses | Terminal adapter that spawns local shell sessions via PTY fork for interactive shell access in the web terminal |
| [claude_code](/docs/generated/web-terminal-adapters-claude_code) | uses | Terminal adapter that spawns Claude Code agent sessions via PTY using claude -p (prompt) or claude -c (interactive) commands |

## Related

### Tasks
- T-967: Session profiles + provider registry for orchestrator readiness (T-962 Phase 4)

---
*Auto-generated from Component Fabric. Card: `web-terminal-adapters-__init__.yaml`*
*Last verified: 2026-09-03*
