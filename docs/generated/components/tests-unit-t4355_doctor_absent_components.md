# t4355_doctor_absent_components

> T-4355 (GitHub #98) — a project that leaves out an optional component on purpose got a permanent `fw doctor` WARN for it. ABSENT_COMPONENTS lists such components; doctor then reports OK "absent by choice".

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4355_doctor_absent_components.bats`

## What It Does

T-4355 (GitHub #98) — a project that leaves out an optional component on purpose
got a permanent `fw doctor` WARN for it. ABSENT_COMPONENTS lists such components;
doctor then reports OK "absent by choice". An undeclared missing component still
WARNs, and an unknown name in the list WARNs, so a typo cannot silence anything.
TermLink and Node.js are hidden with a PATH that links every host command except
those two (same technique as t4332).

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4355_doctor_absent_components.yaml`*
*Last verified: 2026-11-11*
