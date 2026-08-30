# upgrade_marked_region

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/upgrade_marked_region.bats`

## What It Does

T-3150 — `fw upgrade` step [1/10] rebuilt a consumer's CLAUDE.md as
(everything above `## Core Principle`) + (framework governance). What survived
was decided by where an author happened to put a heading, so a consumer that
organised its governance coherently — its own completion rules next to the
framework's completion rules, i.e. BELOW that line — lost them silently on
every upgrade. Three project-authored sections went that way in one upgrade of
a live consumer.
The fix replaces the positional contract with a declared one: a
`<!-- project-owned: begin -->` / `<!-- project-owned: end -->` region survives
wherever it sits.

---
*Auto-generated from Component Fabric. Card: `tests-unit-upgrade_marked_region.yaml`*
*Last verified: 2026-08-26*
