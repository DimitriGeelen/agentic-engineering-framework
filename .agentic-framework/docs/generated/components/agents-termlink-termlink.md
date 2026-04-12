# termlink

> TermLink integration wrapper: spawn, exec, dispatch, cleanup, status. Adds task-tagging and budget checks around the termlink binary.

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

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `lib/config.sh` | calls |

## Used By (3)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |
| `tests/unit/termlink.bats` | tested_by |
| `tests/unit/termlink.bats` | called_by |

## Related

### Tasks
- T-798: Shellcheck cleanup: remaining peripheral agent scripts
- T-822: Complete fw_config migration — remaining hardcoded settings in hooks and lib scripts
- T-843: Fix TermLink cleanup killing active dispatch workers
- T-881: Upgrade consumer projects with T-879 xargs fix and T-880 init improvements
- T-972: Pickup: TermLink cleanup kills active dispatch workers — fw termlink cleanup treats running workers as orphans because they lack exit_code file (from 999-Agentic-Engineering-Framework)

---
*Auto-generated from Component Fabric. Card: `agents-termlink-termlink.yaml`*
*Last verified: 2026-03-23*
