# discoveries

> Flask blueprint serving /discoveries route. Displays audit discovery findings with WARN/FAIL status from cron and manual audits.

**Type:** route | **Subsystem:** watchtower-web-ui | **Location:** `web/blueprints/discoveries.py`

**Tags:** `web`, `blueprint`, `watchtower`

## What It Does

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| `?` | uses | — |
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [discoveries](/docs/generated/web-templates-discoveries) | renders | Jinja2 template rendering the discoveries page. Shows audit discovery results with pass/warn/fail indicators. |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-discoveries.yaml`*
*Last verified: 2026-03-04*
