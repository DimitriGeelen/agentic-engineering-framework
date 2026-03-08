# shared

> Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering)

**Type:** library | **Subsystem:** watchtower | **Location:** `web/shared.py`

**Tags:** `flask`, `web-ui`, `shared`, `navigation`

## What It Does

Path resolution

## Used By (13)

| Component | Relationship |
|-----------|-------------|
| `C-003` | called_by |
| `web/app.py` | called_by |
| `web/blueprints/cockpit.py` | called_by |
| `web/blueprints/core.py` | called_by |
| `web/blueprints/enforcement.py` | called_by |
| `web/blueprints/fabric.py` | called_by |
| `web/blueprints/inception.py` | called_by |
| `web/blueprints/metrics.py` | called_by |
| `web/blueprints/quality.py` | called_by |
| `web/blueprints/risks.py` | called_by |
| `web/blueprints/session.py` | called_by |
| `web/blueprints/tasks.py` | called_by |
| `web/blueprints/timeline.py` | called_by |

## Related

### Tasks
- T-194: ISO 27001-aligned assurance model — control register, OE testing, risk-driven cron redesign
- T-215: Component Fabric — Watchtower UI page (visual browser + graph)
- T-241: Wire discovery findings into session-start and Watchtower

---
*Auto-generated from Component Fabric. Card: `web-shared.yaml`*
*Last verified: 2026-02-20*
