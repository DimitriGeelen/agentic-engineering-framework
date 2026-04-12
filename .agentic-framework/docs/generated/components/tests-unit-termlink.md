# termlink

> Unit tests for agents/termlink/termlink.sh (8 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/termlink.bats`

**Tags:** `termlink`, `bats`, `unit-test`

## What It Does

Unit tests for agents/termlink/termlink.sh
Origin: T-930

### Framework Reference

The Task tool and TermLink dispatch are two different mechanisms for parallel work. **Choose based on the work type:**

| Factor | Task tool agent | TermLink dispatch (`fw termlink dispatch`) |
|--------|----------------|---------------------------------------------|
| Edit/Write tools | Yes (sub-agent) | Yes (spawns full `claude -p` worker) |
| Context isolation | No (shares parent context window) | Yes (independent process, zero context cost) |
| Max parallel | 5 (hard limit) | Unlimited (real OS processes) |
| Observable from outside | No | Yes (attach, stream, output) |
| Survives context

*(truncated — see CLAUDE.md for full section)*

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `agents/termlink/termlink.sh` | calls |

## Related

### Tasks
- T-930: Add unit tests for agents/termlink/termlink.sh

---
*Auto-generated from Component Fabric. Card: `tests-unit-termlink.yaml`*
*Last verified: 2026-04-05*
