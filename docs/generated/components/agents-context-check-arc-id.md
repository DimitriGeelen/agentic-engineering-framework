# check-arc-id

> TODO: describe what this component does

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-arc-id.sh`

## What It Does

T-1849: arc_id task-frontmatter validation hook (bash wrapper for Python).
The fw hook dispatcher (bin/fw:5489) loads .sh files; the actual logic
lives in check-arc-id.py to keep YAML parsing + arc resolution clean.

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [arc_id_validation_guard](/docs/generated/tests-unit-arc_id_validation_guard) | called_by | TODO: describe what this component does |
| [arc_id_validation_guard](/docs/generated/tests-unit-arc_id_validation_guard) | tests_by | TODO: describe what this component does |
| [hook-config](/docs/generated/hook-config) | called_by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [settings_regenerate_preserves_hooks](/docs/generated/tests-unit-settings_regenerate_preserves_hooks) | called_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-arc-id.yaml`*
*Last verified: 2026-05-16*
