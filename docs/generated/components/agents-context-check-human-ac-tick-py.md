# check-human-ac-tick

> T-1731: Human-AC tick guard hook.

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-human-ac-tick.py`

## What It Does

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [verification-port](/docs/generated/lib-verification-port) | calls | lib/verification-port.sh — hard-coded Watchtower port detection (T-2732) |
| [comment_strip](/docs/generated/lib-comment_strip) | calls | Structural HTML-comment stripping — the single canonical rule (T-2954). |
| [check-active-task](/docs/generated/agents-context-check-active-task) | calls | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-human-ac-tick](/docs/generated/agents-context-check-human-ac-tick) | called_by | T-1731: Human-AC tick guard hook (bash wrapper for the Python implementation). The fw hook dispatcher (bin/fw:4759) loads .sh files; the actual logic lives in check-human-ac-tick.py for clean diff parsing. |
| [comment_strip](/docs/generated/lib-comment_strip) | called_by | Structural HTML-comment stripping — the single canonical rule (T-2954). |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-human-ac-tick-py.yaml`*
*Last verified: 2026-09-03*
