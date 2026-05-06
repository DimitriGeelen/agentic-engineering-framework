# test_doctor_scope_tags

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_doctor_scope_tags.bats`

## What It Does

T-1707 / G-065 Stream 2 — fw doctor scope tagging.
Origin: T-1702 deferred. Original incident (2026-05-03 housekeeping)
was an agent bundling host-level findings (git identity, bats not
installed) into project housekeeping. Tagging host findings makes
the boundary unambiguous so an agent doesn't confuse machine-level
config with project-level config.
These tests pin:
- The _doctor_warn_host helper exists in bin/fw
- 12 host-scope WARN emits route through the helper
- The summary line shows "(N host-level)" when host_warnings > 0

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_doctor_scope_tags.yaml`*
*Last verified: 2026-05-03*
