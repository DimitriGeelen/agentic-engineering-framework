# integration-suite

> agents/audit/integration-suite.sh — T-4634: scheduled tests/integration run.

**Type:** script | **Subsystem:** audit | **Location:** `agents/audit/integration-suite.sh`

## What It Does

agents/audit/integration-suite.sh — T-4634: scheduled tests/integration run.
tests/integration ran in no gate: not at commit, not at pre-push, not in the
nightly unit-suite run (T-4596 RCA — claude_fw_restart_terminator.bats broke
twice unseen). This runs it with the unit-suite runner (per-file pool, per-file
cap, overlap lock, report schema) into its OWN report directory and lock, so it
never shares the unit suite's report, ratchet baseline or lock.
`fw audit` grades the report (check_integration_suite_report). There is no
integration baseline: every red FAILs, and the reds go to tasks.
Every FW_UNIT_SUITE_* override still applies; the defaults below are the
integration ones (measured in T-4634: see the task's ## Decisions).

---
*Auto-generated from Component Fabric. Card: `agents-audit-integration-suite.yaml`*
*Last verified: 2026-10-22*
