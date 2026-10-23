# t4358_doctor_turn_driver_interactive

> T-4358 (GH #101) — doctor must not WARN "TURN DRIVER is not armed" for an ordinary interactive claude-fw session.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4358_doctor_turn_driver_interactive.bats`

## What It Does

T-4358 (GH #101) — doctor must not WARN "TURN DRIVER is not armed" for an
ordinary interactive claude-fw session. The wrapper records a `start` event
on every launch, so the turn-driver sub-check runs for every session; only an
ARMED state (enabled: true) that has stopped is the T-3225 failure worth a
WARN. Never armed, or deliberately disarmed, is informational.
The block under test is taken from bin/fw itself (the turn-driver sub-check
inside the Continuous-run `start|iterate` branch) and run against fixture
projects with the real lib/continuous-mode.sh.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4358_doctor_turn_driver_interactive.yaml`*
*Last verified: 2026-10-20*
