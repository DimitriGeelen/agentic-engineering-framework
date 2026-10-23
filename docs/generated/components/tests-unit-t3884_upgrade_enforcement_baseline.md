# t3884_upgrade_enforcement_baseline

> T-3884: fw upgrade step [10/10] said "Enforcement baseline exists" after step 5 had rewritten .claude/settings.json, and the next `fw doctor` FAILed "Enforcement baseline CHANGED" (ring20-manager, 1.8.0 -> 1.8.2).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3884_upgrade_enforcement_baseline.bats`

## What It Does

T-3884: fw upgrade step [10/10] said "Enforcement baseline exists" after step 5
had rewritten .claude/settings.json, and the next `fw doctor` FAILed
"Enforcement baseline CHANGED" (ring20-manager, 1.8.0 -> 1.8.2). The baseline
guards against hook tampering, so the fix must not launder a drift that
existed BEFORE the upgrade: refresh only when it matched before.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3884_upgrade_enforcement_baseline.yaml`*
*Last verified: 2026-10-05*
