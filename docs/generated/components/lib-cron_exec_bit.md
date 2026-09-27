# cron_exec_bit

> T-3380: scripts a deployed crontab invokes DIRECTLY must be executable.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/cron_exec_bit.py`

## What It Does

Basenames that mean "the next token is a script argument, not a command".

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [exec-bit-drift](/docs/generated/lib-exec-bit-drift) | calls | lib/exec-bit-drift.sh — T-3317 (OBS-336): exec-bit drift detector. |
| [liveness-check](/docs/generated/agents-monitor-liveness-check) | calls | Cron liveness monitor (every 1 min, T-1269/T-1273): checks TermLink hub, framework agent, Claude instance and Watchtower; appends .context/monitors/liveness.jsonl and writes liveness-latest.yaml. |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [t3380_cron_exec_bit](/docs/generated/tests-unit-t3380_cron_exec_bit) | tests_by | T-3380 — a script the deployed crontab execs DIRECTLY must be executable. |

---
*Auto-generated from Component Fabric. Card: `lib-cron_exec_bit.yaml`*
*Last verified: 2026-09-17*
