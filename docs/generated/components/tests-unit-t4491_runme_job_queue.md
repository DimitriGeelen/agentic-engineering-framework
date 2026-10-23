# t4491_runme_job_queue

> T-4491: runme job queue, slice 1 of the T-4470 GO.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4491_runme_job_queue.bats`

## What It Does

T-4491: runme job queue, slice 1 of the T-4470 GO. Each of the six review findings in
docs/reports/T-4470-runme-job-queue.md §6 has a test here proving it cannot happen in
AEF's version (all six are red against a launcher that sources the job into its own
shell), plus prerequisite 5 (the queue is never a Tier 0 authorisation) and 832's
field lessons from addendum 1 (readiness probe, staged index named, 80-column pty,
names not row numbers).

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4491_runme_job_queue.yaml`*
*Last verified: 2026-10-20*
