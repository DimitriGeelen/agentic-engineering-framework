# t3878_runme_pending

> T-3878: a `fw runme watch` dies with the session that armed it, so an operator's run after an agent restart went unobserved (832 T-1050; here the pre-reboot waits ended "stopped").

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3878_runme_pending.bats`

## What It Does

T-3878: a `fw runme watch` dies with the session that armed it, so an
operator's run after an agent restart went unobserved (832 T-1050; here the
pre-reboot waits ended "stopped"). The watch now records who armed it, and
`fw runme pending` names WATCH LOST / RUN IN FLIGHT / RUN ENDED WITHOUT RECORD.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3878_runme_pending.yaml`*
*Last verified: 2026-10-05*
