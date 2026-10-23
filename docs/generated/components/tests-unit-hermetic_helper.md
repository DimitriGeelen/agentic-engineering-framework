# hermetic_helper

> T-4378 — the shared hermetic fixture (tests/unit/helpers/hermetic.bash) does what it says: env stripped, private TMPDIR and project, and every tripwire fires on a deliberate leak.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/hermetic_helper.bats`

## What It Does

T-4378 — the shared hermetic fixture (tests/unit/helpers/hermetic.bash) does what
it says: env stripped, private TMPDIR and project, and every tripwire fires on a
deliberate leak. The leaks below are aimed at fakes, never at the real checkout.

---
*Auto-generated from Component Fabric. Card: `tests-unit-hermetic_helper.yaml`*
*Last verified: 2026-10-19*
