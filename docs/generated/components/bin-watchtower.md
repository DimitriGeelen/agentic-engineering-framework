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

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `?` | uses |

## Related

### Tasks
- T-250: Reliable Watchtower startup script

---
*Auto-generated from Component Fabric. Card: `bin-watchtower.yaml`*
*Last verified: 2026-03-04*
