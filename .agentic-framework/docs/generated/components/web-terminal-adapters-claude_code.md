# claude_code

> Terminal adapter that spawns Claude Code agent sessions via PTY using claude -p (prompt) or claude -c (interactive) commands

**Type:** script | **Subsystem:** watchtower | **Location:** `web/terminal/adapters/claude_code.py`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [costs](/docs/generated/lib-costs) | calls | Token usage tracking from JSONL transcripts — parses Claude Code session data for cost reporting (T-801) |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [terminal](/docs/generated/web-blueprints-terminal) | called_by | Flask blueprint providing the interactive web terminal API with session creation, I/O, resize, and profile-based configuration |

## Related

### Tasks
- T-967: Session profiles + provider registry for orchestrator readiness (T-962 Phase 4)

---
*Auto-generated from Component Fabric. Card: `web-terminal-adapters-claude_code.yaml`*
*Last verified: 2026-04-06*
