# upgrade_fresh_machine_simulation_vendored

> T-1635 / T-2793 / T-3671: fresh-machine simulation, fw-init-vendored consumers.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/upgrade_fresh_machine_simulation_vendored.bats`

## What It Does

T-1635 / T-2793 / T-3671: fresh-machine simulation, fw-init-vendored consumers.
Split from upgrade_fresh_machine_simulation.bats (T-3747): each test here builds
a consumer with a real `fw init` (~60s), and together they pushed the single
file past the unit runner's 900s per-file cap under full-suite load. Same
scrubbed-env guard, same §Consumer-Facing Command Hygiene obligation: keep green.

---
*Auto-generated from Component Fabric. Card: `tests-unit-upgrade_fresh_machine_simulation_vendored.yaml`*
*Last verified: 2026-10-04*
