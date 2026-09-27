# arc_id_validation_guard

> T-1849: arc_id task-frontmatter validation guard — unit tests.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/arc_id_validation_guard.bats`

## What It Does

T-1849: arc_id task-frontmatter validation guard — unit tests.
Closes Q1 from arc-grooming inception (T-1846): hostage state where a task
references a non-existent arc. PreToolUse hook check-arc-id.py refuses
writes under agent control when arc_id is set + non-empty + does not
resolve to .context/arcs/*.yaml. Empty/missing arc_id passes through.
Predicated on T-1848 D-Immutability — valid refs stay valid forever.

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-arc-id](/docs/generated/agents-context-check-arc-id) | calls | T-1849: arc_id task-frontmatter validation hook (bash wrapper for Python). The fw hook dispatcher (bin/fw:5489) loads .sh files; the actual logic lives in check-arc-id.py to keep YAML parsing + arc resolution clean. |
| [check-arc-id](/docs/generated/agents-context-check-arc-id) | tests | T-1849: arc_id task-frontmatter validation hook (bash wrapper for Python). The fw hook dispatcher (bin/fw:5489) loads .sh files; the actual logic lives in check-arc-id.py to keep YAML parsing + arc resolution clean. |
| [check-arc-id](/docs/generated/agents-context-check-arc-id-py) | tests | T-1849: arc_id task-frontmatter validation hook (T-NEW-2). |

---
*Auto-generated from Component Fabric. Card: `tests-unit-arc_id_validation_guard.yaml`*
*Last verified: 2026-05-16*
