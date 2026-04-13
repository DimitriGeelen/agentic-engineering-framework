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

## Dependencies (28)

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
| `web/search_utils.py` | calls |
| `web/blueprints/__init__.py` | calls |
| `web/embeddings.py` | calls |

## Used By (6)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |
| `web/templates/_partials/badge.html` | used-by |
| `web/test_costs.py` | called_by |
| `web/templates/_partials/badge.html` | used-by_by |

## Related

### Tasks
- T-865: Fix Fabric Explorer naming — use project_name in title
- T-881: Upgrade consumer projects with T-879 xargs fix and T-880 init improvements
- T-964: Watchtower single terminal — xterm.js + Flask-SocketIO PTY bridge (T-962 Phase 1)
- T-965: Multi-session terminal tabs + session management (T-962 Phase 2)
- T-966: TermLink session observation in Watchtower terminal (T-962 Phase 3)

---
*Auto-generated from Component Fabric. Card: `web-app.yaml`*
*Last verified: 2026-02-20*
