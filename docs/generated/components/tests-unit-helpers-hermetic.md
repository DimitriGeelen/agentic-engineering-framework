# hermetic

> tests/unit/helpers/hermetic.bash — one hermetic fixture for bats (T-4378).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/helpers/hermetic.bash`

## What It Does

tests/unit/helpers/hermetic.bash — one hermetic fixture for bats (T-4378).
Replaces the per-file fixtures that each fixed only the leak their author had
already hit (T-2746 env -i temp dir, T-4313 project marker, T-4318 private
TMPDIR, T-4315 sidecar, t4347 PROJECT_ROOT). The pytest twin is
tests/unit/hermetic.py; keep the two contracts the same.
load helpers/hermetic
setup()    { hermetic_setup --project; }   # or no flag: an empty non-project dir
teardown() { hermetic_teardown; }
Each test gets:
HERMETIC_ROOT     private mktemp dir, removed at teardown

---
*Auto-generated from Component Fabric. Card: `tests-unit-helpers-hermetic.yaml`*
*Last verified: 2026-10-19*
