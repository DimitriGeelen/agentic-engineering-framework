# t4424_upgrade_flag_declaration

> T-4424: the bare-from-consumer handoff replay (T-4405) kept '-*' words and dropped every other word as the positional target, so a value-taking flag added later would reach upstream without its value, and the value would be swallowed as…

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4424_upgrade_flag_declaration.bats`

## What It Does

T-4424: the bare-from-consumer handoff replay (T-4405) kept '-*' words and dropped
every other word as the positional target, so a value-taking flag added later
would reach upstream without its value, and the value would be swallowed as the
target. The flag grammar is now declared once in lib/upgrade.sh
(_FW_UPGRADE_VALUE_FLAGS / _FW_UPGRADE_SWITCH_FLAGS); the parser and the replay
both read it, and the replay refuses an undeclared flag.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4424_upgrade_flag_declaration.yaml`*
*Last verified: 2026-10-19*
