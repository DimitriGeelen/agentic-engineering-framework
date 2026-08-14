# test_frontmatter_loader_equivalence

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_frontmatter_loader_equivalence.py`

## What It Does

Skip the whole module when the installed PyYAML has no C extension: there is
no second loader to compare against, and parse_frontmatter has already fallen
back to SafeLoader, so there is nothing this test could assert.

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_frontmatter_loader_equivalence.yaml`*
*Last verified: 2026-08-03*
