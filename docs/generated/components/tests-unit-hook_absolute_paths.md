# hook_absolute_paths

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/hook_absolute_paths.bats`

## What It Does

T-1364 (G-053-A): Unit tests for absolute hook paths in .claude/settings.json.
Claude Code resolves hook commands against the session CWD. When CWD drifts
(test fixtures, subdir navigation), relative paths like "bin/fw hook X"
cascade into tool-blocks. Fix: emit absolute paths at init/upgrade time.
$target_dir is canonicalized via `cd && pwd` in both entry points.

---
*Auto-generated from Component Fabric. Card: `tests-unit-hook_absolute_paths.yaml`*
*Last verified: 2026-04-20*
