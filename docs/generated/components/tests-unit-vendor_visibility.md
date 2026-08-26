# vendor_visibility

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/vendor_visibility.bats`

## What It Does

T-3144 — `fw vendor` writes executable code into a consumer tree and never
checked that the consumer's git could see it. Reported by 010-termlink for
`tools/`; the measured set is wider.
ON "FAILS AGAINST PRE-CHANGE CODE" (AC6). It does, and that measurement is
worth almost nothing: before this task `fw_vendor_check_visibility` did not
exist, so every test below fails by NameError rather than by disagreeing with
a behaviour. Same degenerate control as T-3138's lint.
The tests that carry real weight are the three marked [instrument]. Each one
is a false positive this check ACTUALLY SHIPPED WITH during T-3144, caught by
running it against real trees rather than by reading it:

---
*Auto-generated from Component Fabric. Card: `tests-unit-vendor_visibility.yaml`*
*Last verified: 2026-08-25*
