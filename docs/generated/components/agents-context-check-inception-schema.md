# check-inception-schema

> T-2188: inception frontmatter schema validation hook (bash wrapper for Python). The fw hook dispatcher loads .sh files; logic lives in check-inception-schema.py.

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-inception-schema.sh`

## What It Does

T-2188: inception frontmatter schema validation hook (bash wrapper for Python).
The fw hook dispatcher loads .sh files; logic lives in check-inception-schema.py.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-inception-schema](/docs/generated/agents-context-check-inception-schema-py) | calls | T-2188: PreToolUse hook validating inception frontmatter schema. |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook-config](/docs/generated/hook-config) | called_by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [settings_regenerate_preserves_hooks](/docs/generated/tests-unit-settings_regenerate_preserves_hooks) | called_by | T-2710: a forced .claude/settings.json regenerate must not silently delete hooks that `fw hook-enable` added after init. |
| [enrich](/docs/generated/agents-fabric-lib-enrich) | called_by | Fabric enrichment engine — auto-detect dependency edges from source analysis. |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-inception-schema.yaml`*
*Last verified: 2026-06-02*
