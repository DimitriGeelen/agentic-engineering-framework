# t3906_upgrade_project_hooks_not_a_gap

> T-3906 — a consumer's OWN hooks are not a hook gap.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3906_upgrade_project_hooks_not_a_gap.bats`

## What It Does

T-3906 — a consumer's OWN hooks are not a hook gap.
832 on 1.8.3 (2026-10-05): step 5 printed "PARTIAL  Hooks regenerated but
gap remains: missing 0 hook(s): ." and the run ended "Upgrade PARTIAL",
although every framework hook was present. Cause: _t2912_hook_gap added
non-framework (project) hooks into the "stale" count; the regenerator
CARRIES them, so every consumer with its own hooks regenerated on every
upgrade ("N hardcoded paths") and then reported a gap it could never close,
naming only the missing count.
Real `fw upgrade` subprocess under env -i against a real vendored consumer,
same harness shape as t2912_upgrade_hook_regen_convergence.bats. The

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3906_upgrade_project_hooks_not_a_gap.yaml`*
*Last verified: 2026-10-05*
