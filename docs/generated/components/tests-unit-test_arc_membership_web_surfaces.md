# test_arc_membership_web_surfaces

> T-1879 (T-NEW-14): silent-corpus #2 sweep — web surfaces must read both `arc_id:` frontmatter (T-1849 canonical, T-1850 migrated) AND legacy `arc:<slug>` tag.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_arc_membership_web_surfaces.py`

## What It Does

Arc YAML — in-progress, slug "test-arc-X" with numeric id "arc-099"

## Dependencies (9)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [core](/docs/generated/web-blueprints-core) | calls | Flask blueprint: Core |
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [tasks](/docs/generated/web-blueprints-tasks) | calls | Flask blueprint: Tasks |
| [arc](/docs/generated/lib-arc) | calls | lib/arc.sh — Arc system (T-1653 Phase 1 / T-1661 / T-1848) |
| [core](/docs/generated/web-blueprints-core) | registers | Flask blueprint: Core |
| [core](/docs/generated/web-blueprints-core) | uses | Flask blueprint: Core |
| [app](/docs/generated/web-app) | uses | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [shared](/docs/generated/web-shared) | uses | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [tasks](/docs/generated/web-blueprints-tasks) | uses | Flask blueprint: Tasks |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_arc_membership_web_surfaces.yaml`*
*Last verified: 2026-05-17*
