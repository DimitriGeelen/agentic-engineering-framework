# t4582_termlink_wait_missed_event

> T-4582 — `fw termlink wait --name W` must not idle the full timeout when W emitted worker.done before the wait subscribed.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4582_termlink_wait_missed_event.bats`

## What It Does

T-4582 — `fw termlink wait --name W` must not idle the full timeout when W emitted
worker.done before the wait subscribed. The stub termlink's `event wait` never sees an
event (it sleeps its whole --timeout), which is exactly the missed-event case; the wait
must still return as soon as W's exit_code is on disk, and never run past --timeout.
Fixture FW_DISPATCH_DIR only, never the real /tmp/tl-dispatch.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4582_termlink_wait_missed_event.yaml`*
*Last verified: 2026-10-22*
