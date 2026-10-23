# t3882_upgrade_cron_next_step

> T-3882: fw upgrade adds framework cron jobs to the registry (step 3b) but the "run 'fw cron install' to deploy" hint was one mid-run line; 832 counted a dry run as the install.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3882_upgrade_cron_next_step.bats`

## What It Does

T-3882: fw upgrade adds framework cron jobs to the registry (step 3b) but the
"run 'fw cron install' to deploy" hint was one mid-run line; 832 counted a
dry run as the install. The closing next steps now name the jobs that are
not running yet.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3882_upgrade_cron_next_step.yaml`*
*Last verified: 2026-10-05*
