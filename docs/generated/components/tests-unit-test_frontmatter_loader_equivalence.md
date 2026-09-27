# test_frontmatter_loader_equivalence

> T-2774: the fast YAML loader must parse identically to the pure-Python one.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_frontmatter_loader_equivalence.py`

## What It Does

Skip the whole module when the installed PyYAML has no C extension: there is
no second loader to compare against, and parse_frontmatter has already fallen
back to SafeLoader, so there is nothing this test could assert.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [shared](/docs/generated/web-shared) | uses | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_frontmatter_loader_equivalence.yaml`*
*Last verified: 2026-08-03*
