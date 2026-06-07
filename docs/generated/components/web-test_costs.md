# test_costs

> 24 pytest tests for costs blueprint — _fmt_tokens, _parse_session, _load_all_sessions, route (T-810)

**Type:** test | **Subsystem:** tests | **Location:** `web/test_costs.py`

**Tags:** `tokens`, `costs`, `testing`

## What It Does

── Fixtures ────────────────────────────────────────────────────

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [costs](/docs/generated/web-blueprints-costs) | calls | Watchtower /costs page — token usage dashboard with session table and project summary (T-802) |
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [costs](/docs/generated/web-blueprints-costs) | registers | Watchtower /costs page — token usage dashboard with session table and project summary (T-802) |

## Related

### Tasks
- T-810: Unit tests for web/blueprints/costs.py token dashboard
- T-881: Upgrade consumer projects with T-879 xargs fix and T-880 init improvements

---
*Auto-generated from Component Fabric. Card: `web-test_costs.yaml`*
*Last verified: 2026-04-03*
