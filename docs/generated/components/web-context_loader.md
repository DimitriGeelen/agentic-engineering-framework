# context_loader

> Centralized YAML loading for context project files (learnings, patterns, decisions, practices, concerns, directives). Replaces duplicated try/except blocks across blueprints. Uses shared.load_yaml() for error collection.

**Type:** script | **Subsystem:** watchtower | **Location:** `web/context_loader.py`

**Tags:** `python`, `yaml`, `context`, `watchtower`, `loading`

## What It Does

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | calls |

## Used By (10)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/discovery.py` | calls |
| `web/blueprints/core.py` | calls |
| `web/blueprints/metrics.py` | calls |
| `web/blueprints/risks.py` | calls |
| `C-003` | called_by |
| `web/blueprints/core.py` | called_by |
| `web/blueprints/metrics.py` | called_by |
| `web/blueprints/risks.py` | called_by |
| `web/blueprints/quality.py` | called_by |
| `web/blueprints/discovery.py` | called_by |

---
*Auto-generated from Component Fabric. Card: `web-context_loader.yaml`*
*Last verified: 2026-03-11*
