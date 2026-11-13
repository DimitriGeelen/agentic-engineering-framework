# t5088_fabric_register_not_refused

> T-5088 (GitHub #108) — `fw fabric register` wrote the card, exited 0, and printed "REFUSED: ... no subsystem rule matches". Output and exit code disagreed.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5088_fabric_register_not_refused.bats`

## What It Does

T-5088 (GitHub #108) — `fw fabric register` wrote the card, exited 0, and printed
"REFUSED: ... no subsystem rule matches". Output and exit code disagreed. The card is
written on purpose (T-3430: leave a field unfilled rather than guess), so the output now
says which fields were NOT FILLED and how to fill them.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5088_fabric_register_not_refused.yaml`*
*Last verified: 2026-11-12*
