# bus-handler

> Processes incoming bus messages from the inbox directory. Triggered by systemd.path when files appear in .context/bus/inbox/. Routes typed YAML envelopes to appropriate handlers for sub-agent result management.

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/bus-handler.sh`

## What It Does

bus-handler.sh — Process incoming bus messages from inbox
Triggered by systemd.path when files appear in .context/bus/inbox/
Part of: Agentic Engineering Framework (T-110 spike)

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [bus](/docs/generated/lib-bus) | reads | fw bus - Task-scoped result ledger for sub-agent communication — _Processes messages in .context/bus/inbox/ written by the bus system_ |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |

---
*Auto-generated from Component Fabric. Card: `agents-context-bus-handler.yaml`*
*Last verified: 2026-03-01*
