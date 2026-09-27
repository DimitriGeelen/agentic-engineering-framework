# t3281_cron_orphan_scan

> T-3281: orphaned cron.d entries — deployed jobs whose declared PROJECT_ROOT is gone.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3281_cron_orphan_scan.bats`

## What It Does

T-3281: orphaned cron.d entries — deployed jobs whose declared PROJECT_ROOT is gone.
The control that matters is C2. A scan that reports every entry it sees would
pass C1 and look like working detection; only the clean-host leg separates
"detects orphans" from "always says orphan". Same shape as the negative control
in tests/unit/t3275_delivery_confirmation.bats — a fixture that cannot fail is
the failure mode this file exists to avoid.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [cron-orphans](/docs/generated/lib-cron-orphans) | tests | lib/cron-orphans.sh — detect deployed cron entries whose declared PROJECT_ROOT is gone (T-3281). |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3281_cron_orphan_scan.yaml`*
*Last verified: 2026-09-05*
