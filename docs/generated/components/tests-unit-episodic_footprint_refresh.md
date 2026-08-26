# episodic_footprint_refresh

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/episodic_footprint_refresh.bats`

## What It Does

T-3130 — the episodic's git footprint is mined before the commit it describes.
WHY THE NAIVE TEST DOES NOT WORK (AC2, and the whole point of this file)
The obvious control is: complete a task, commit, assert `commits > 0`.
That control PASSES AGAINST UNFIXED CODE, and it passes for a reason that has
nothing to do with the fix. By the time it asserts, the commit exists — so if
anything re-reads git at any point (a later regeneration, a second update, a
test helper that regenerates), the value is right for the wrong reason. It is
measuring from a vantage point where both the broken and the fixed system look
identical, which makes it indistinguishable from a test that asserts nothing.
The value has to be captured AT GENERATION — before the commit lands — and

---
*Auto-generated from Component Fabric. Card: `tests-unit-episodic_footprint_refresh.yaml`*
*Last verified: 2026-08-25*
