# t3257-livefire-backlog

> T-3257 — the backlog proof T-3255 designed, on a substrate that can actually run it.

**Type:** script | **Subsystem:** framework-core | **Location:** `tools/t3257-livefire-backlog.sh`

## What It Does

T-3257 — the backlog proof T-3255 designed, on a substrate that can actually run it.
WHAT T-3255 GOT RIGHT, AND WHY ITS RUN COULD NEVER HAPPEN.
T-3255's harness (tools/t3255-livefire-agent.sh) is correct in every part that
matters: a real Claude agent reads a backlog, does ONE item, ticks it, ends its
turn — a genuine early stop with work remaining and no budget event anywhere
near it. That is exactly the `exit no-signal` case M2 cannot reach, reproduced
rather than simulated. Its assertions are reproduced here almost verbatim.
What it could not do is reach the agent. It spawns the session with
`termlink spawn --shell -- bash -lc '… exec claude …'`, which nests as:
tmux pane -> termlink register -> inner PTY -> shell -> claude TUI

---
*Auto-generated from Component Fabric. Card: `tools-t3257-livefire-backlog.yaml`*
*Last verified: 2026-09-05*
