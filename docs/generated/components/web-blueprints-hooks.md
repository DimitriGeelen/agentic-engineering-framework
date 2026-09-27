# hooks

> T-1632 (B-3c of T-1626) — Watchtower /hooks page.

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/hooks.py`

## What It Does

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [hooks](/docs/generated/web-templates-hooks) | renders | Git-hooks status dashboard, rendered by web/blueprints/hooks.py. |
| [hook-threshold](/docs/generated/lib-hook-threshold) | calls | T-1631 (B-3b of T-1626) — hook-failure threshold rule. |
| [shared](/docs/generated/web-shared) | uses | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | uses_by | Flask blueprint:   Init |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-hooks.yaml`*
*Last verified: 2026-05-01*
