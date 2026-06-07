# costs

> Watchtower /costs page — token usage dashboard with session table and project summary (T-802)

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/costs.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [costs](/docs/generated/web-templates-costs) | renders | Jinja2 template for token usage dashboard — summary cards, breakdown bar, session table (T-802) |

## Used By (10)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [__init__](/docs/generated/web-blueprints-__init__) | calls | Flask blueprint:   Init |
| [core](/docs/generated/web-blueprints-core) | calls | Flask blueprint: Core |
| [test_costs](/docs/generated/web-test_costs) | called-by | 24 pytest tests for costs blueprint — _fmt_tokens, _parse_session, _load_all_sessions, route (T-810) |
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [core](/docs/generated/web-blueprints-core) | called_by | Flask blueprint: Core |
| [core](/docs/generated/web-blueprints-core) | registered_by | Flask blueprint: Core |
| [test_costs](/docs/generated/web-test_costs) | registered_by | 24 pytest tests for costs blueprint — _fmt_tokens, _parse_session, _load_all_sessions, route (T-810) |
| [test_costs](/docs/generated/web-test_costs) | called_by | 24 pytest tests for costs blueprint — _fmt_tokens, _parse_session, _load_all_sessions, route (T-810) |

## Related

### Tasks
- T-881: Upgrade consumer projects with T-879 xargs fix and T-880 init improvements

---
*Auto-generated from Component Fabric. Card: `web-blueprints-costs.yaml`*
*Last verified: 2026-04-03*
