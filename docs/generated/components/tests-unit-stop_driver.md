# stop_driver

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/stop_driver.bats`

## What It Does

T-3164 (arc-012 S1) — the continuous-run turn driver.
The assertions that matter are the ones about what the driver REFUSES to do. A
Stop hook that continues when it should not takes the operator's session away
from them, so every test below is written so that removing the guard it covers
turns it red.

---
*Auto-generated from Component Fabric. Card: `tests-unit-stop_driver.yaml`*
*Last verified: 2026-08-26*
