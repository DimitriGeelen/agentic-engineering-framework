# t4524_unit_suite_session_env

> T-4524: the unit-suite runner must not hand an agent session's variables (CLAUDECODE=1, CLAUDE_*, TERMLINK_SESSION_ID, FW_DISPATCHED_WORKER, ...) to the tests it runs.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4524_unit_suite_session_env.bats`

## What It Does

T-4524: the unit-suite runner must not hand an agent session's variables
(CLAUDECODE=1, CLAUDE_*, TERMLINK_SESSION_ID, FW_DISPATCHED_WORKER, ...) to the
tests it runs. ring20's clean-room run launched the suite from a Claude Code
session and every agent-refusal path in every test took its agent branch.
HERMETIC BY CONSTRUCTION: the runner is pointed at a fixture corpus in
$BATS_TEST_TMPDIR. The real tests/unit corpus is never run.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4524_unit_suite_session_env.yaml`*
*Last verified: 2026-10-21*
