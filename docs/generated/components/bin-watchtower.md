# watchtower

> Launcher script for Watchtower web dashboard. Starts Flask app on configured port with optional debug mode.

**Type:** script | **Subsystem:** watchtower-web-ui | **Location:** `bin/watchtower.sh`

**Tags:** `bin`, `watchtower`, `web`

## What It Does

Watchtower — Reliable start/stop/restart for the Web UI (T-250)
Inspired by DenkraumNavigator/restart_server_prod.sh
Usage:
bin/watchtower.sh start [--port N] [--debug]
bin/watchtower.sh stop
bin/watchtower.sh restart [--port N] [--debug]
bin/watchtower.sh status

### Framework Reference

**Watchtower's port is per-project, not hard-coded to `3000`.** Two consumer projects on one host would collide if the framework assumed 3000 everywhere.

Resolution order (T-885, T-1287, T-1376):

1. **`.context/working/watchtower.url`** — triple-file source of truth, written by `bin/watchtower.sh` on start. Read this file, don't guess.
2. **`bin/fw config get PORT`** — per-project `FW_PORT` config when no Watchtower is currently running.
3. **`3000`** — default ONLY when neither of the above is available (fresh project, no config, no running instance).

*(truncated — see CLAUDE.md for full section)*

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| `?` | uses | — |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |
| [firewall](/docs/generated/lib-firewall) | calls | Opens UFW firewall ports for TCP traffic when starting network services, with no-op fallback if UFW is not installed or inactive |
| [watchtower](/docs/generated/lib-watchtower) | calls | Detects the running Watchtower instance URL and provides browser-open helpers for scripts that need to link to the web UI |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [watchtower_url_refresh](/docs/generated/tests-unit-watchtower_url_refresh) | called_by | TODO: describe what this component does |
| [watchtower_url_refresh](/docs/generated/tests-unit-watchtower_url_refresh) | tests_by | TODO: describe what this component does |

## Related

### Tasks
- T-822: Complete fw_config migration — remaining hardcoded settings in hooks and lib scripts
- T-881: Upgrade consumer projects with T-879 xargs fix and T-880 init improvements
- T-888: Extract ensure_firewall_open to lib/firewall.sh for reuse

---
*Auto-generated from Component Fabric. Card: `bin-watchtower.yaml`*
*Last verified: 2026-03-04*
