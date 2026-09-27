# stop_driver

> T-3164 (arc-012 S1) — the continuous-run turn driver.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/stop_driver.bats`

## What It Does

T-3164 (arc-012 S1) — the continuous-run turn driver.
The assertions that matter are the ones about what the driver REFUSES to do. A
Stop hook that continues when it should not takes the operator's session away
from them, so every test below is written so that removing the guard it covers
turns it red.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [stop-driver](/docs/generated/agents-context-stop-driver) | tests | Stop hook — the continuous-run turn driver (T-3164, arc-012 S1). |

---
*Auto-generated from Component Fabric. Card: `tests-unit-stop_driver.yaml`*
*Last verified: 2026-08-26*
