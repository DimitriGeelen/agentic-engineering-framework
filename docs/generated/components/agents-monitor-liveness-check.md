# liveness-check

> Cron liveness monitor (every 1 min, T-1269/T-1273): checks TermLink hub, framework agent, Claude instance and Watchtower; appends .context/monitors/liveness.jsonl and writes liveness-latest.yaml.

**Type:** script | **Subsystem:** audit | **Location:** `agents/monitor/liveness-check.sh`

## What It Does

liveness-check.sh — TermLink hub + framework agent + Claude instance + Watchtower liveness
T-1269/T-1273: runs every 1 minute via cron and on @reboot
Outputs: .context/monitors/liveness.jsonl (append-only), liveness-latest.yaml (snapshot)

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [cron_exec_bit](/docs/generated/lib-cron_exec_bit) | called_by | T-3380: scripts a deployed crontab invokes DIRECTLY must be executable. |
| [t3380_cron_exec_bit](/docs/generated/tests-unit-t3380_cron_exec_bit) | tests_by | T-3380 — a script the deployed crontab execs DIRECTLY must be executable. |

---
*Auto-generated from Component Fabric. Card: `agents-monitor-liveness-check.yaml`*
*Last verified: 2026-04-15*
