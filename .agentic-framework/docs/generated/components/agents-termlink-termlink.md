# termlink

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `agents/termlink/termlink.sh`

## What It Does

termlink.sh — Framework wrapper for TermLink cross-terminal communication
Thin wrapper around the `termlink` binary. Adds framework concerns
(task-tagging, budget checks, cleanup tracking) but delegates all
real work to the binary. Adapted from tl-dispatch.sh (T-143, tested
with 3 parallel workers).
TermLink repo: https://onedev.docker.ring20.geelenandcompany.com/termlink
Install: cargo install --path crates/termlink-cli
Part of: Agentic Engineering Framework (T-503, from T-502 inception)

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

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |

## Related

### Tasks
- T-502: TermLink integration — cross-terminal session communication for framework
- T-503: TermLink Phase 0 build — doctor check, agents/termlink/, fw route, CLAUDE.md
- T-504: Add fw termlink update subcommand + daily update check cron
- T-577: PICKUP-007: TermLink run timeout creates orphaned processes
- T-652: TermLink dispatch task enforcement — make --task mandatory in fw termlink dispatch

---
*Auto-generated from Component Fabric. Card: `agents-termlink-termlink.yaml`*
*Last verified: 2026-03-23*
