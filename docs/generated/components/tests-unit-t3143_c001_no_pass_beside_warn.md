# t3143_c001_no_pass_beside_warn

> T-3143: audit C-001 must not print its "All inceptions have research artifacts" PASS in the same run as its own C-001 WARN.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3143_c001_no_pass_beside_warn.bats`

## What It Does

T-3143: audit C-001 must not print its "All inceptions have research artifacts"
PASS in the same run as its own C-001 WARN.
The PASS was gated on c001_missing alone; an "unreferenced" artefact WARNed
without touching that counter, so an unreferenced-only corpus printed both.
Two-sided: the unreferenced fixture gets the WARN and no PASS; the same fixture
with the artefact referenced gets the PASS and no WARN.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3143_c001_no_pass_beside_warn.yaml`*
*Last verified: 2026-10-20*
