# t4427_secret_scan_timing_line

> T-4427: T-4400 sped up the pre-commit secret scan on fw init's T-000 bootstrap commit, but the field test could not measure it (dimitri-mint-dev T-155, INCONCLUSIVE): the hook swallows the scanner's output on success, so nothing timed the…

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4427_secret_scan_timing_line.bats`

## What It Does

T-4427: T-4400 sped up the pre-commit secret scan on fw init's T-000 bootstrap
commit, but the field test could not measure it (dimitri-mint-dev T-155,
INCONCLUSIVE): the hook swallows the scanner's output on success, so nothing
timed the scan on its own. scan-staged now records
"secret scan: N file(s) in S.s s" to FW_SECRET_SCAN_TIMING_FILE, and fw init
prints it under the bootstrap-commit line. Verdicts and exit codes unchanged.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4427_secret_scan_timing_line.yaml`*
*Last verified: 2026-10-19*
