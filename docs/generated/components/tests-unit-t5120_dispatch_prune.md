# t5120_dispatch_prune

> T-5120 (010 T-3777) — `fw termlink prune`: unattended retention for FINISHED worker dirs. Removes only this project's dirs that are finished (review: finalised), collected and older than the age cut; keeps everything else; signals nothing.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5120_dispatch_prune.bats`

## What It Does

T-5120 (010 T-3777) — `fw termlink prune`: unattended retention for FINISHED worker dirs.
Removes only this project's dirs that are finished (review: finalised), collected and older
than the age cut; keeps everything else; signals nothing. `fw termlink dispatch` kicks it in
the background at most hourly (_retention_kick), off when TERMLINK_DISPATCH_RETENTION_DAYS=0.
Sandbox only: FW_DISPATCH_DIR / FW_DISPATCH_LEGACY_DIR under BATS_TEST_TMPDIR, termlink stubbed.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5120_dispatch_prune.yaml`*
*Last verified: 2026-11-13*
