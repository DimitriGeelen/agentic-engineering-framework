# base

> SessionAdapter protocol — defines the interface for terminal session backends (local shell, Claude Code). Used by terminal blueprint.

**Type:** protocol | **Subsystem:** watchtower | **Location:** `web/terminal/adapters/base.py`

**Tags:** `protocol`, `terminal`, `adapter`

## What It Does

### Framework Reference

> **⚠ KNOWN CONFLICT — read before following this section (T-100201).** The
> "session runs on `master`, commits go straight to master" mechanism below
> **contradicts the T-2394 master-merge-only gate** (`agents/git/lib/master-guard.sh`),
> which is **live in this repo** (`PROTECT_MASTER=1`) and structurally BLOCKS any
> direct authored commit on `master`. A fast-forward never fires the guard; a direct
> commit does. This conflict was hit live on 2026-07-05 (operator got
> `BLOCKED: direct commit on 'master' — master is merge-only`).
>
> **Interim safe rule (until T-100201 resolves the mechan

*(truncated — see CLAUDE.md for full section)*

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
