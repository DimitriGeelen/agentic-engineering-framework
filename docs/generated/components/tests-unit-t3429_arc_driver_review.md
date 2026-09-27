# t3429_arc_driver_review

> T-3429 (arc-006, D-586): the external value-driver reviewer.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3429_arc_driver_review.bats`

## What It Does

T-3429 (arc-006, D-586): the external value-driver reviewer.
Pins the three static checks against crafted fixture arcs — each check failing
on a fixture built to fail exactly it, and passing on a valid one. The point of
a STATIC reviewer is that its verdict is re-runnable; these tests are what make
that claim falsifiable.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3429_arc_driver_review.yaml`*
*Last verified: 2026-09-22*
