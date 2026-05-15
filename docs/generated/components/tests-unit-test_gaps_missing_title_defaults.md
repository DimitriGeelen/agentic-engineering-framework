# test_gaps_missing_title_defaults

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_gaps_missing_title_defaults.bats`

## What It Does

T-1840 — fw gaps defensive .get() for missing 'title' / 'id' fields.
Origin: consumer email-archive (framework:pickup offset 2, 2026-05-04)
reported fw gaps crashing with KeyError: 'title' on a project whose
.context/project/concerns.yaml predated the title-field requirement.
Direct dict subscript at bin/fw:4864 killed the CLI on the first malformed
entry; consumer had to backfill all 8 entries with derived titles before
fw gaps would render anything.
These tests pin:
- missing 'title' field renders as <untitled>, doesn't crash
- well-formed entries (title + id present) render unchanged

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_gaps_missing_title_defaults.yaml`*
*Last verified: 2026-05-14*
