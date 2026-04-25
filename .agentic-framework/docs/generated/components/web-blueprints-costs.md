# costs

> Watchtower /costs page — token usage dashboard with session table and project summary (T-802)

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/costs.py`

## What It Does

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | calls |
| `web/templates/costs.html` | renders |

## Used By (10)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/__init__.py` | calls |
| `web/blueprints/core.py` | calls |
| `web/test_costs.py` | called-by |
| `web/blueprints/__init__.py` | called_by |
| `web/blueprints/__init__.py` | registered_by |
| `web/blueprints/core.py` | called_by |
| `web/blueprints/core.py` | registered_by |
| `web/test_costs.py` | registered_by |
| `web/test_costs.py` | called_by |

## Related

### Tasks
- T-881: Upgrade consumer projects with T-879 xargs fix and T-880 init improvements

---
*Auto-generated from Component Fabric. Card: `web-blueprints-costs.yaml`*
*Last verified: 2026-04-03*
