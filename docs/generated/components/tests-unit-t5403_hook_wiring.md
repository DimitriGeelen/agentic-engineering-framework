# t5403_hook_wiring

> T-5403: the operator wires hooks (operator ruling 2026-11-24, "a").

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5403_hook_wiring.bats`

## What It Does

T-5403: the operator wires hooks (operator ruling 2026-11-24, "a"). An agent's Write/Edit that
changes the hook wiring of .claude/settings.json is refused, Bash writes to the file are
refused, and `fw hook-wiring propose` prepares the change as an operator runme.
Hermetic: every settings file is a fixture under a temp dir.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5403_hook_wiring.yaml`*
*Last verified: 2026-11-24*
