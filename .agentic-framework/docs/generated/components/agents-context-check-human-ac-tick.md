# check-human-ac-tick

> TODO: describe what this component does

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-human-ac-tick.sh`

## What It Does

T-1731: Human-AC tick guard hook (bash wrapper for the Python implementation).
The fw hook dispatcher (bin/fw:4759) loads .sh files; the actual logic lives
in check-human-ac-tick.py for clean diff parsing.

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook-config](/docs/generated/hook-config) | called_by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-human-ac-tick.yaml`*
*Last verified: 2026-05-05*
