#!/usr/bin/env python3
"""T-5117 — a green verdict that exists but does not count is named, never silent.

055 field report (their T-645, msgs 73f57250 / a56f7da3, 2026-11-13): `fw reviewer verdict apply`
returned ticked/refused/skipped all empty while `satisfying_verdict` had judged the green stale,
and the partial-complete close re-run printed "Update Complete". Nobody could see why the box
stayed open.

Fixture repos only (the T-3580 round-3 harness); no real task is judged.
"""
import io
import sys
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import verdict_ledger as vl  # noqa: E402
from _review_runtime import hermetic_review_env  # noqa: E402,F401  (autouse)
from t3580_judge_cli_test import TID, repo  # noqa: E402,F401
from t3580_round3_test import prod  # noqa: E402,F401
from t4779_stale_review_release_test import _reviewed, _task_commit  # noqa: E402


def _stale(root):
    _reviewed(root)
    _task_commit(root, {"src/new.py": "x = 1\n"}, f"{TID}: change after review")


def test_a_stale_green_is_reported_as_not_applied(prod):
    _stale(prod)
    res = vl.apply(TID, prod)
    assert res["ticked"] == []
    assert [n["ac"] for n in res["not_applied"]] == [1]
    assert "stale-review" in res["not_applied"][0]["why"]


def test_not_applied_is_not_refused(prod):
    _stale(prod)
    res = vl.apply(TID, prod)
    assert res["refused"] == []


def test_cli_prints_one_line_and_keeps_exit_zero(prod, monkeypatch):
    _stale(prod)
    monkeypatch.setenv("PROJECT_ROOT", str(prod))
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        assert vl._cli(["apply", TID]) == 0
    lines = [ln for ln in err.getvalue().splitlines() if ln.startswith("NOT APPLIED:")]
    assert len(lines) == 1, err.getvalue()
    assert TID in lines[0] and "AC1" in lines[0] and "stale-review" in lines[0]


def test_control_no_verdict_is_not_reported(prod, monkeypatch):
    res = vl.apply(TID, prod)
    assert res["not_applied"] == []
    monkeypatch.setenv("PROJECT_ROOT", str(prod))
    err = io.StringIO()
    with redirect_stdout(io.StringIO()), redirect_stderr(err):
        assert vl._cli(["apply", TID]) == 0
    assert "NOT APPLIED" not in err.getvalue()


def test_control_a_valid_green_ticks_and_is_not_reported(prod):
    _reviewed(prod)
    res = vl.apply(TID, prod)
    assert [t["ac"] for t in res["ticked"]] == [1]
    assert res["not_applied"] == []
