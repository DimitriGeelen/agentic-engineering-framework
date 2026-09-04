# session

> Provider-neutral dataclass defining the terminal session descriptor schema with metadata, capabilities, and process info

**Type:** script | **Subsystem:** watchtower | **Location:** `web/terminal/session.py`

## What It Does

### Framework Reference

**Async, parallel, or observable framework work runs through TermLink
(`claude-fw --termlink`), not through Claude Code's own background-job
daemon.** This is a distinct layer from the Sub-Agent Dispatch Protocol and
the Built-in Task Tool Ban above: those govern dispatch *inside* a running
conversation (Task-tool agents, TermLink workers); this governs how the
*session itself* was launched, before any conversation starts.

*(truncated — see CLAUDE.md for full section)*

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [terminal](/docs/generated/web-blueprints-terminal) | called_by | Flask blueprint providing the interactive web terminal API with session creation, I/O, resize, and profile-based configuration |
| [registry](/docs/generated/web-terminal-registry) | called_by | Provides CRUD operations and YAML file persistence for terminal session records stored in .context/sessions/ |
| [terminal](/docs/generated/web-blueprints-terminal) | uses_by | Flask blueprint providing the interactive web terminal API with session creation, I/O, resize, and profile-based configuration |
| [registry](/docs/generated/web-terminal-registry) | uses_by | Provides CRUD operations and YAML file persistence for terminal session records stored in .context/sessions/ |

## Related

### Tasks
- T-967: Session profiles + provider registry for orchestrator readiness (T-962 Phase 4)

---
*Auto-generated from Component Fabric. Card: `web-terminal-session.yaml`*
*Last verified: 2026-04-06*
