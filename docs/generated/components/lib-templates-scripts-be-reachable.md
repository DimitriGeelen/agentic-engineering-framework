# be-reachable

> Template skill script: one-command opt-in to agent-presence for ephemeral claude-code sessions (T-1841, /be-reachable)

**Type:** script | **Subsystem:** termlink-integration | **Location:** `lib/templates/scripts/be-reachable.sh`

## What It Does

T-1841 — be-reachable wrapper for ephemeral claude-code sessions.
One-command opt-in to agent-presence (T-1830). Backgrounds
listener-heartbeat.sh (T-1832), persists PID + agent_id in
~/.termlink/be-reachable.state, applies sensible defaults so a
claude-code session becomes reachable via T-1834 --to auto-discover
in under 30 seconds.
Mirrors the persistent-host rail (T-1840 systemd template) but for
session-lifetime instances that should die with the terminal.
Subcommands:
start [--agent-id X] [--pty-session Y] [--listen-topic T]... [--role R]

---
*Auto-generated from Component Fabric. Card: `lib-templates-scripts-be-reachable.yaml`*
*Last verified: 2026-09-08*
