# watchtower-rss-sample

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `agents/monitor/watchtower-rss-sample.sh`

## What It Does

watchtower-rss-sample.sh — periodic RSS/CPU sample of the Watchtower process
T-1615 (T-1611-B): every 5 min via cron. Used to distinguish memory-leak
re-saturation from request-rate queueing. If RSS climbs monotonically over
many hours, T-1612's threaded=True fix is incomplete and T-1611-C (gunicorn
swap) reopens. If RSS stays bounded, the cheap fix is sufficient.
Outputs:
.context/monitors/watchtower-rss.jsonl       — append-only history
.context/monitors/watchtower-rss-latest.yaml — most recent sample
Pattern matches agents/monitor/liveness-check.sh (T-1269/T-1273).

---
*Auto-generated from Component Fabric. Card: `agents-monitor-watchtower-rss-sample.yaml`*
*Last verified: 2026-04-30*
