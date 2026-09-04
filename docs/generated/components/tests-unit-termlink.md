# termlink

> Unit tests for agents/termlink/termlink.sh (8 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/termlink.bats`

**Tags:** `termlink`, `bats`, `unit-test`

## What It Does

Unit tests for agents/termlink/termlink.sh
Origin: T-930

### Framework Reference

**Async, parallel, or observable framework work runs through TermLink
(`claude-fw --termlink`), not through Claude Code's own background-job
daemon.** This is a distinct layer from the Sub-Agent Dispatch Protocol and
the Built-in Task Tool Ban above: those govern dispatch *inside* a running
conversation (Task-tool agents, TermLink workers); this governs how the
*session itself* was launched, before any conversation starts.

*(truncated — see CLAUDE.md for full section)*

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [termlink](/docs/generated/agents-termlink-termlink) | calls | TermLink integration wrapper: spawn, exec, dispatch, cleanup, status. Adds task-tagging and budget checks around the termlink binary. |
| [termlink](/docs/generated/agents-termlink-termlink) | tests | TermLink integration wrapper: spawn, exec, dispatch, cleanup, status. Adds task-tagging and budget checks around the termlink binary. |

## Related

### Tasks
- T-930: Add unit tests for agents/termlink/termlink.sh

---
*Auto-generated from Component Fabric. Card: `tests-unit-termlink.yaml`*
*Last verified: 2026-04-05*
