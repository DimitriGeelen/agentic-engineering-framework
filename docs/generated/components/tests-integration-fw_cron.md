# fw_cron

> Integration tests for fw cron CLI — 9 tests covering help, status, list, invalid subcommand, run/pause/resume without job-id.

**Type:** test | **Subsystem:** framework-core | **Location:** `tests/integration/fw_cron.bats`

**Tags:** `bats`, `integration-test`, `cron`, `cli`

## What It Does

Integration tests for fw cron subcommand
Tests the CLI interface for cron job management:
fw cron status     — show registry status
fw cron list       — alias for status
fw cron generate   — regenerate crontab from registry
fw cron run <id>   — run a job immediately
fw cron pause <id> — pause a job
fw cron resume <id> — resume a paused job

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_cron.yaml`*
*Last verified: 2026-03-29*
