# t2859_work_on_usage_examples

> T-2859 — `fw work-on` usage text advertised `fw work-on "Fix login bug" --description "Details here"` with no --type.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t2859_work_on_usage_examples.bats`

## What It Does

T-2859 — `fw work-on` usage text advertised `fw work-on "Fix login bug"
--description "Details here"` with no --type. create-task.sh fails fast on a
missing --type whenever stdin is not a tty (T-100160), which is every agent
session, cron job and dispatch worker — so the example shown to a stuck new
user could never work. This test RUNS every create-form example the usage
text prints, off-tty, so a usage line and the parser cannot drift apart again.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2859_work_on_usage_examples.yaml`*
*Last verified: 2026-10-20*
