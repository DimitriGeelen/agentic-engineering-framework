# liveness-check

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `agents/monitor/liveness-check.sh`

## What It Does

liveness-check.sh — TermLink hub + framework agent + Claude instance + Watchtower liveness
T-1269/T-1273: runs every 1 minute via cron and on @reboot
Outputs: .context/monitors/liveness.jsonl (append-only), liveness-latest.yaml (snapshot)

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |

---
*Auto-generated from Component Fabric. Card: `agents-monitor-liveness-check.yaml`*
*Last verified: 2026-04-15*
