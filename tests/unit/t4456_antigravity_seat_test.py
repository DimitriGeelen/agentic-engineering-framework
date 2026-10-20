"""T-4456 — an antigravity seat that exits 0 because headless mode auto-denied its command tool
is reported unavailable with that reason, not as a bare 'exit 0'."""
from __future__ import annotations

import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib.reviewer import judge_cli  # noqa: E402
from _review_runtime import hermetic_review_env  # noqa: E402,F401  (autouse)
import t3852_unavailable_seat_test as ut  # noqa: E402
from t3852_unavailable_seat_test import wdirs  # noqa: E402,F401

DENIED = ("jetski: no output produced — a tool required the command permission that headless "
          "mode cannot prompt for, so it was auto-denied. Add an allow-rule under permissions.allow\n")


def test_exit_zero_with_an_auto_denied_command_tool_is_named(wdirs):
    ut._dead_seat(wdirs, "judge-a-1", exit_code=0)
    (wdirs / "judge-a-1" / "result.md").write_text(DENIED)
    assert judge_cli._unavailable_reason("judge-a-1") == "tool permission auto-denied (headless) (exit 0)"


def test_the_denial_in_stderr_is_found_too(wdirs):
    ut._dead_seat(wdirs, "judge-a-2", exit_code=0)
    (wdirs / "judge-a-2" / "stderr.log").write_text(DENIED)
    assert "auto-denied" in judge_cli._unavailable_reason("judge-a-2")


def test_control_a_silent_exit_zero_stays_a_bare_exit(wdirs):
    ut._dead_seat(wdirs, "judge-a-3", exit_code=0)
    assert judge_cli._unavailable_reason("judge-a-3") == "exit 0"
