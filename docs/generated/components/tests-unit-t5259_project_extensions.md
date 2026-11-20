# t5259_project_extensions

> T-5259 (T-4649 slice 0) — project extensions register.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5259_project_extensions.bats`

## What It Does

T-5259 (T-4649 slice 0) — project extensions register.
Every modification of the framework in a project is the project operator's
recorded decision (.framework-extensions.yaml at the project root), listed by
fw audit and kept by fw vendor / fw upgrade. vendored-override entries are
mirrored into .fwvendor-preserve.yaml so the existing T-3850/T-4870 protection
keeps them. FIXTURES ONLY: every test runs in a temporary project root.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5259_project_extensions.yaml`*
*Last verified: 2026-11-19*
