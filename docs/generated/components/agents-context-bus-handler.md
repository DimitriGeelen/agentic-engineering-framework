# bus-handler

> Processes incoming bus messages from the inbox directory. Triggered by systemd.path when files appear in .context/bus/inbox/. Routes typed YAML envelopes to appropriate handlers for sub-agent result management.

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/bus-handler.sh`

## What It Does

bus-handler.sh — Process incoming bus messages from inbox
Triggered by systemd.path when files appear in .context/bus/inbox/
Part of: Agentic Engineering Framework (T-110 spike)

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `lib/bus.sh` | reads |

---
*Auto-generated from Component Fabric. Card: `agents-context-bus-handler.yaml`*
*Last verified: 2026-03-01*
