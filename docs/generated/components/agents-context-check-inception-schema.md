# check-inception-schema

> TODO: describe what this component does

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-inception-schema.sh`

## What It Does

T-2188: inception frontmatter schema validation hook (bash wrapper for Python).
The fw hook dispatcher loads .sh files; logic lives in check-inception-schema.py.

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook-config](/docs/generated/hook-config) | called_by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [settings_regenerate_preserves_hooks](/docs/generated/tests-unit-settings_regenerate_preserves_hooks) | called_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-inception-schema.yaml`*
*Last verified: 2026-06-02*
