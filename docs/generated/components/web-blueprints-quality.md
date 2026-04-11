# quality

> Flask blueprint: Quality

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/quality.py`

## What It Does

_load_latest_audit moved to web.shared.load_latest_audit (T-431/A7)

## Dependencies (4)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | calls |
| `web/templates/quality.html` | renders |
| `web/subprocess_utils.py` | calls |
| `web/context_loader.py` | calls |

## Used By (4)

| Component | Relationship |
|-----------|-------------|
| `web/app.py` | called_by |
| `web/app.py` | registered_by |
| `web/blueprints/__init__.py` | called_by |
| `web/blueprints/__init__.py` | registered_by |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-quality.yaml`*
*Last verified: 2026-02-20*
