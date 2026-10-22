#!/usr/bin/env bash
# agents/audit/integration-suite.sh — T-4634: scheduled tests/integration run.
#
# tests/integration ran in no gate: not at commit, not at pre-push, not in the
# nightly unit-suite run (T-4596 RCA — claude_fw_restart_terminator.bats broke
# twice unseen). This runs it with the unit-suite runner (per-file pool, per-file
# cap, overlap lock, report schema) into its OWN report directory and lock, so it
# never shares the unit suite's report, ratchet baseline or lock.
# `fw audit` grades the report (check_integration_suite_report). There is no
# integration baseline: every red FAILs, and the reds go to tasks.
#
# Every FW_UNIT_SUITE_* override still applies; the defaults below are the
# integration ones (measured in T-4634: see the task's ## Decisions).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"

export FW_UNIT_SUITE_DIR="${FW_UNIT_SUITE_DIR:-$FRAMEWORK_ROOT/tests/integration}"
export FW_UNIT_SUITE_REPORT_DIR="${FW_UNIT_SUITE_REPORT_DIR:-$PROJECT_ROOT/.context/audits/integration-suite}"
export FW_UNIT_SUITE_LOCK="${FW_UNIT_SUITE_LOCK:-$PROJECT_ROOT/.context/locks/integration-suite.lock}"
export FW_UNIT_SUITE_JOBS="${FW_UNIT_SUITE_JOBS:-4}"
export FW_UNIT_SUITE_FILE_TIMEOUT="${FW_UNIT_SUITE_FILE_TIMEOUT:-900}"
export FW_UNIT_SUITE_TIMEOUT="${FW_UNIT_SUITE_TIMEOUT:-3600}"
export FW_UNIT_SUITE_PY_RESERVE="${FW_UNIT_SUITE_PY_RESERVE:-600}"

exec bash "$SCRIPT_DIR/unit-suite.sh" "$@"
