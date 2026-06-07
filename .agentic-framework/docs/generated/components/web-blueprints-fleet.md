# fleet

> TODO: describe what this component does

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/fleet.py`

## What It Does

Try PATH first

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [fleet](/docs/generated/web-templates-fleet) | renders | Watchtower /fleet dashboard template — renders fleet health summary, per-host status badges, last-seen timestamps, and TermLink reachability, consuming data assembled by web/blueprints/fleet.py |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-fleet.yaml`*
*Last verified: 2026-04-24*
