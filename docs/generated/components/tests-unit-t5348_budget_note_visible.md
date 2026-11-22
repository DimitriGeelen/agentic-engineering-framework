# t5348_budget_note_visible

> T-5348 (G-139 cause B): the harness shows only about the first 2KB of the SessionStart injection.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5348_budget_note_visible.bats`

## What It Does

T-5348 (G-139 cause B): the harness shows only about the first 2KB of the SessionStart
injection. The T-1728 budget note was appended last (byte 111,887 of 112,928 in the
session that found this), so a resumed agent never saw it and repeated a stop
recommendation made at ~750K while the gauge read Green at 260K.
These tests run the real hook per source and assert the short note is in the first 2000
bytes, before "## Where We Are", and names what is stale and where the live band is.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5348_budget_note_visible.yaml`*
*Last verified: 2026-11-21*
