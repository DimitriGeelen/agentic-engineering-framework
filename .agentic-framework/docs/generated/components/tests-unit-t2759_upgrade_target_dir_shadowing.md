# t2759_upgrade_target_dir_shadowing

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2759_upgrade_target_dir_shadowing.bats`

## What It Does

T-2759: `fw upgrade` must never write a consumer's files somewhere else and
then report success.
THE DEFECT
do_upgrade binds target_dir to the consumer at lib/upgrade.sh:566. The shim
migration block at :1305 declared `local target_dir` a SECOND time, inside the
same function. Bash does not create a new scope for that — it rebinds the
existing one. From that line on, target_dir was
dirname(readlink -f ~/.local/bin/fw).
Steps 5-10 then wrote .claude/settings.json, .mcp.json, resume.md, scripts/,
the .context subdirs, the .framework.yaml version pin and the enforcement

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2759_upgrade_target_dir_shadowing.yaml`*
*Last verified: 2026-08-03*
