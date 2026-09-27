# check-inception-decisions

> T-1984: inception_decisions / unlocks_inception_decision validation hook (bash wrapper). The fw hook dispatcher (bin/fw:5639) loads .sh files; actual logic in check-inception-decisions.py.

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-inception-decisions.sh`

## What It Does

T-1984: inception_decisions / unlocks_inception_decision validation hook (bash wrapper).
The fw hook dispatcher (bin/fw:5639) loads .sh files; actual logic in check-inception-decisions.py.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-inception-decisions](/docs/generated/agents-context-check-inception-decisions-py) | calls | T-1984: inception_decisions task-frontmatter validation hook. |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook-config](/docs/generated/hook-config) | called_by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [settings_regenerate_preserves_hooks](/docs/generated/tests-unit-settings_regenerate_preserves_hooks) | called_by | T-2710: a forced .claude/settings.json regenerate must not silently delete hooks that `fw hook-enable` added after init. |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-inception-decisions.yaml`*
*Last verified: 2026-05-22*
