# t2990_root_pollution

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2990_root_pollution.bats`

## What It Does

T-2990: the root-pollution rail, proven in BOTH directions.
The rail exists because four ImageMagick PostScript files accumulated in the
repo root over three months and nothing noticed. A rail that only ever passes
would reproduce exactly that state while looking like coverage (L-543), so the
planted-junk case below carries as much weight as the clean-root one.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2990_root_pollution.yaml`*
*Last verified: 2026-08-14*
