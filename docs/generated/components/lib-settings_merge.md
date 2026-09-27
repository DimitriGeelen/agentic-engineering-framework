# settings_merge

> T-2710 — carry non-template config forward across a settings.json regenerate.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/settings_merge.py`

## What It Does

`<anything>/fw hook <name>` or bare `fw hook <name>`. The \b keeps it from
matching a binary merely ENDING in fw (e.g. "myfw hook x").

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [init](/docs/generated/lib-init) | calls | fw init - Bootstrap a new project with the Agentic Engineering Framework |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [settings_regenerate_preserves_hooks](/docs/generated/tests-unit-settings_regenerate_preserves_hooks) | tests_by | T-2710: a forced .claude/settings.json regenerate must not silently delete hooks that `fw hook-enable` added after init. |

---
*Auto-generated from Component Fabric. Card: `lib-settings_merge.yaml`*
*Last verified: 2026-08-01*
