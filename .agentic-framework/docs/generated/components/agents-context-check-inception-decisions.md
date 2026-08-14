# check-inception-decisions

> TODO: describe what this component does

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-inception-decisions.sh`

## What It Does

T-1984: inception_decisions / unlocks_inception_decision validation hook (bash wrapper).
The fw hook dispatcher (bin/fw:5639) loads .sh files; actual logic in check-inception-decisions.py.

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook-config](/docs/generated/hook-config) | called_by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-inception-decisions.yaml`*
*Last verified: 2026-05-22*
