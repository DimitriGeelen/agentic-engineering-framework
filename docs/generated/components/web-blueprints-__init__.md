# __init__

> Flask blueprint:   Init  

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/__init__.py`

## What It Does

Flask blueprints for the Agentic Engineering Framework web UI
Centralizes blueprint registration (T-431/A2).
Adding a new blueprint: import it here and append to _BLUEPRINTS.

## Dependencies (50)

| Target | Relationship |
|--------|-------------|
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
| `web/blueprints/discoveries.py` | calls |
| `web/blueprints/docs.py` | calls |
| `web/blueprints/settings.py` | calls |
| `web/blueprints/cron.py` | calls |
| `web/blueprints/api.py` | calls |
| `web/blueprints/approvals.py` | calls |
| `web/blueprints/review.py` | calls |
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
| `web/blueprints/discoveries.py` | registers |
| `web/blueprints/docs.py` | registers |
| `web/blueprints/settings.py` | registers |
| `web/blueprints/cron.py` | registers |
| `web/blueprints/api.py` | registers |
| `web/blueprints/approvals.py` | registers |
| `web/blueprints/review.py` | registers |
| `web/blueprints/discovery.py` | calls |
| `web/blueprints/costs.py` | calls |
| `web/blueprints/config.py` | calls |
| `web/blueprints/terminal.py` | calls |
| `web/blueprints/sessions.py` | calls |
| `web/blueprints/discovery.py` | registers |
| `web/blueprints/costs.py` | registers |
| `web/blueprints/config.py` | registers |
| `web/blueprints/terminal.py` | registers |
| `web/blueprints/sessions.py` | registers |
| `web/blueprints/prompts.py` | calls |
| `web/blueprints/prompts.py` | registers |

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `web/app.py` | imported_by |
| `web/app.py` | called_by |

## Related

### Tasks
- T-819: Build lib/config.sh — 3-tier config resolution for framework settings
- T-881: Upgrade consumer projects with T-879 xargs fix and T-880 init improvements
- T-964: Watchtower single terminal — xterm.js + Flask-SocketIO PTY bridge (T-962 Phase 1)
- T-983: Watchtower sessions page — list active terminal sessions with status and controls

---
*Auto-generated from Component Fabric. Card: `web-blueprints-__init__.yaml`*
*Last verified: 2026-03-01*
