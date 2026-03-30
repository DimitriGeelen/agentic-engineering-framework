# settings

> Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state.

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/settings.py`

## What It Does

## Dependencies (3)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | imports |
| `web/shared.py` | calls |
| `web/templates/settings.html` | renders |

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/__init__.py` | called_by |
| `web/blueprints/__init__.py` | registered_by |

## Related

### Tasks
- T-722: Show notification status on Watchtower settings page
- T-724: Sync vendor copies — T-722 settings changes to .agentic-framework

---
*Auto-generated from Component Fabric. Card: `web-blueprints-settings.yaml`*
*Last verified: 2026-03-09*
