# t3380_cron_exec_bit

> T-3380 — a script the deployed crontab execs DIRECTLY must be executable.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3380_cron_exec_bit.bats`

## What It Does

T-3380 — a script the deployed crontab execs DIRECTLY must be executable.
Observed 2026-09-17. agents/monitor/liveness-check.sh was committed 100644.
Cron invoked it every minute (plus @reboot) for 34 days: 13,680 CRON lines in
syslog, every one answered "Permission denied", and the script produced no
output at all from 2026-08-14 onward. That script is the rail that samples
Watchtower liveness — so when a host reboot at 17:09:04 killed Watchtower, the
outage ran 5h35m with nothing reporting it, and was found only because a
human-review handoff could not reach a server.
The T-3317 exec-bit parity check could not see it. Its candidate set is
"files the git index marks 100755", so a file committed 100644 is not examined

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [cron_exec_bit](/docs/generated/lib-cron_exec_bit) | tests | T-3380: scripts a deployed crontab invokes DIRECTLY must be executable. |
| [liveness-check](/docs/generated/agents-monitor-liveness-check) | tests | Cron liveness monitor (every 1 min, T-1269/T-1273): checks TermLink hub, framework agent, Claude instance and Watchtower; appends .context/monitors/liveness.jsonl and writes liveness-latest.yaml. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3380_cron_exec_bit.yaml`*
*Last verified: 2026-09-17*
