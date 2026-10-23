# t4526_tmp_leftovers

> TODO: describe what this component does

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4526_tmp_leftovers.bats`

## What It Does

T-4526: tests and tools left ~406 /tmp/aef-* and /tmp/fw-* entries (1.7 GB)
on the shared host. Each creator removed its temp path on the happy path only.
These tests take an exit path that skips the rm and check nothing stays, plus
the unit-suite runner's own leftover report.
HERMETIC: every run gets TMPDIR=$BATS_TEST_TMPDIR/tmp, so the shared /tmp is
neither read nor written; the runner is pointed at a fixture corpus.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4526_tmp_leftovers.yaml`*
*Last verified: 2026-10-21*
