# t3636_objectives_seed

> TODO: describe what this component does

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3636_objectives_seed.bats`

## What It Does

T-3636 (T-3535 IW-3): every project authors .context/project/objectives.yaml ONCE,
through its own entry point — greenfield T-002, existing-project T-007, or the
one-time task `fw upgrade` seeds (lib/objectives-seed.sh). Never a copy of the
framework's own objectives file (Directive 4).
The end-to-end upgrade leg (vendored consumer, real file:// upstream) lives in
tests/unit/upgrade_fresh_machine_simulation.bats.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3636_objectives_seed.yaml`*
*Last verified: 2026-10-01*
