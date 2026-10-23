# t3160_cron_dry_run_does_not_write

> T-3160 — Regression: 'fw cron install --dry-run' ran the writing generator as its diff step, rewriting the git-tracked .context/cron/agentic-audit.crontab and then printing "(dry-run — no changes made)" (G-087 / 001-CashWeb field report: a…

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3160_cron_dry_run_does_not_write.bats`

## What It Does

T-3160 — Regression: 'fw cron install --dry-run' ran the writing generator
as its diff step, rewriting the git-tracked .context/cron/agentic-audit.crontab
and then printing "(dry-run — no changes made)" (G-087 / 001-CashWeb field
report: a 3875-byte source with ten live jobs truncated to 450 bytes).
Pins:
1. --dry-run leaves the source byte- and mtime-identical, and prints the diff
2. --dry-run against a deployed target still prints a unified diff of the
registry-derived text, and touches neither source nor target
3. --dry-run leaves no scratch file behind
4. without --dry-run, install still generates, writes and installs

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3160_cron_dry_run_does_not_write.yaml`*
*Last verified: 2026-10-20*
