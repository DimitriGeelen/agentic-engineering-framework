# t4450_unit_suite_env_scrub

> T-4450: the unit-suite runner must not hand its own control variables (FW_UNIT_SUITE_TIER, FW_UNIT_SUITE_DIR, ...) to the tests it runs.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4450_unit_suite_env_scrub.bats`

## What It Does

T-4450: the unit-suite runner must not hand its own control variables
(FW_UNIT_SUITE_TIER, FW_UNIT_SUITE_DIR, ...) to the tests it runs. A test that
starts a nested runner on a fixture corpus inherited tier=fast from the
nightly and refused (no tiers.yaml) — t4058 red 5/5 on every run.
HERMETIC BY CONSTRUCTION: the runner is pointed at a fixture corpus in
$BATS_TEST_TMPDIR. The real tests/unit corpus is never run.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4450_unit_suite_env_scrub.yaml`*
*Last verified: 2026-10-20*
