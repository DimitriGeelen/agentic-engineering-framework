# subprocess_utils

> Consistent subprocess execution for git and fw commands. Provides run_git_command() and run_fw_command() with standardized timeouts, encoding, and error handling.

**Type:** script | **Subsystem:** watchtower | **Location:** `web/subprocess_utils.py`

**Tags:** `python`, `subprocess`, `git`, `watchtower`, `reliability`

## What It Does

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | calls |
| `bin/fw` | calls |

## Used By (12)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/session.py` | calls |
| `web/blueprints/core.py` | calls |
| `web/blueprints/quality.py` | calls |
| `web/blueprints/tasks.py` | calls |
| `web/blueprints/metrics.py` | calls |
| `web/blueprints/cockpit.py` | called_by |
| `web/blueprints/core.py` | called_by |
| `web/blueprints/inception.py` | called_by |
| `web/blueprints/metrics.py` | called_by |
| `web/blueprints/quality.py` | called_by |
| `web/blueprints/session.py` | called_by |
| `web/blueprints/tasks.py` | called_by |

---
*Auto-generated from Component Fabric. Card: `web-subprocess_utils.yaml`*
*Last verified: 2026-03-11*
