# t3162_cron_job_exit_status_survives_logger_pipe

> T-3162 — Regression: generated cron lines ended '<cmd> 2>&1 | logger -t agentic-cron', so the pipeline's status was logger's (always 0) and a crashed job looked successful to cron (G-089 / 001-CashWeb field report).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3162_cron_job_exit_status_survives_logger_pipe.bats`

## What It Does

T-3162 — Regression: generated cron lines ended '<cmd> 2>&1 | logger -t agentic-cron',
so the pipeline's status was logger's (always 0) and a crashed job looked
successful to cron (G-089 / 001-CashWeb field report). The fix appends
'; exit ${PIPESTATUS[0]}' after the logger pipe in both generators.
Pins (by EXECUTING the generated line, not by reading it — L-365's ungated
deployed → executable transition is exactly where the masking lived):
1. a failing job's generated line exits with the job's status
2. a succeeding job's generated line exits 0
3. stderr still reaches logger (the T-1720 gain is kept)
4. paused and 2>/dev/null-rewritten lines carry the same suffix

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3162_cron_job_exit_status_survives_logger_pipe.yaml`*
*Last verified: 2026-10-20*
