# app

> Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port

**Type:** entrypoint | **Subsystem:** watchtower | **Location:** `web/app.py`

**Tags:** `flask`, `web-ui`, `entrypoint`

## What It Does

Application factory

### Framework Reference

When building a web application:
1. **Check port availability** before starting (`ss -tlnp | grep :PORT`)
2. **Start the app** and report the URL to the user
3. **Report access options** — localhost, LAN IP (for other devices), internet (if applicable)
4. Never leave a built web app unstarted without informing the user

## Dependencies (25)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | calls |
| `web/blueprints/core.py` | calls |
| `web/blueprints/tasks.py` | calls |
| `web/blueprints/timeline.py` | calls |
| `C-003` | calls |
| `web/blueprints/quality.py` | calls |
| `web/blueprints/session.py` | calls |
| `web/blueprints/metrics.py` | calls |
| `web/blueprints/cockpit.py` | calls |
| `web/blueprints/inception.py` | calls |
| `web/blueprints/enforcement.py` | calls |
| `web/blueprints/risks.py` | calls |
| `web/blueprints/fabric.py` | calls |
| `web/blueprints/core.py` | registers |
| `web/blueprints/tasks.py` | registers |
| `web/blueprints/timeline.py` | registers |
| `C-003` | registers |
| `web/blueprints/quality.py` | registers |
| `web/blueprints/session.py` | registers |
| `web/blueprints/metrics.py` | registers |
| `web/blueprints/cockpit.py` | registers |
| `web/blueprints/inception.py` | registers |
| `web/blueprints/enforcement.py` | registers |
| `web/blueprints/risks.py` | registers |
| `web/blueprints/fabric.py` | registers |

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |

## Related

### Tasks
- T-273: Production readiness — WSGI, health endpoint, config, error handling
- T-277: First deployment — Watchtower to Ring20 production
- T-365: Watchtower /docs route for generated documentation
- T-376: Python dedup: extract search_utils.py from search.py/embeddings.py
- T-379: Settings page with engine selector and config persistence

---
*Auto-generated from Component Fabric. Card: `web-app.yaml`*
*Last verified: 2026-02-20*
