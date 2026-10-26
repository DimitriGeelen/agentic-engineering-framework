#!/usr/bin/env python3
"""T-4779 — a release commit must not make a reviewer verdict stale, and a withdrawal is loud.

832 field report: the release commit names every shipped task and adds only dist/ copies of
the reviewed source plus dist/MANIFEST.yaml. `_stale_fault` counted any non-.context/.tasks
path in a task-naming commit after the reviewed revision as changed work, so every release
withdrew every shipped task's render verdicts for an identical re-review. The withdrawal on
a refused close was also silent: the box was unticked with nothing on stderr.

Fixture repos only (the T-3580 round-3 harness); no real task is judged.
"""
import io
import subprocess
import sys
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import verdict_ledger as vl  # noqa: E402
import _review_runtime as rt  # noqa: E402
from _review_runtime import hermetic_review_env  # noqa: E402,F401  (autouse)
from t3580_judge_cli_test import TID, _git, _ident, repo  # noqa: E402,F401
from t3580_round2_test import _commit_as, _dispatch  # noqa: E402
from t3580_round3_test import _head, _record, _why, prod  # noqa: E402,F401


def _reviewed(root):
    """A green on AC1 for the current HEAD, committed and completed."""
    rev = _head(root)
    _dispatch(root, "rv-1", revision=rev)
    _record(root, "rv-1")
    _commit_as(root, "reviewer-rv-1")
    rt.finish(root, "rv-1")
    return rev


def _task_commit(root, files: dict, msg=f"{TID}: release 0.29.0"):
    for rel, body in files.items():
        p = root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(body)
        _git(root, "add", rel)
    _git(root, "commit", "-q", "-m", msg, env=_ident("Release Bot"))


class TestReleaseCommitIsNotWork:
    def test_dist_copies_and_manifest_do_not_withdraw(self, prod):
        _reviewed(prod)
        _task_commit(prod, {"dist/notes.md": (prod / "notes.md").read_text(),
                            "dist/MANIFEST.yaml": f"version: 0.29.0\ntasks: [{TID}]\n"})
        assert _why(prod) == ""
        assert [t["ac"] for t in vl.apply(TID, prod)["ticked"]] == [1]

    def test_a_change_reverted_before_close_is_not_work(self, prod):
        _reviewed(prod)
        _task_commit(prod, {"notes.md": "temporarily different\n"}, f"{TID}: try something")
        _task_commit(prod, {"notes.md": "notes v1\n"}, f"{TID}: revert it")
        assert _why(prod) == ""

    def test_negative_control_a_real_source_change_still_withdraws(self, prod):
        _reviewed(prod)
        _task_commit(prod, {"notes.md": "notes v2\n",
                            "dist/notes.md": "notes v2\n"})
        why = _why(prod)
        assert "stale-review" in why and "touches notes.md" in why

    def test_negative_control_a_hand_edit_outside_dist_withdraws(self, prod):
        _reviewed(prod)
        _task_commit(prod, {"src/new.py": "x = 1\n"}, f"{TID}: add code")
        assert "src/new.py" in _why(prod)


class TestWithdrawalIsLoud:
    def test_apply_cli_prints_one_line_per_withdrawal_on_stderr(self, prod, monkeypatch):
        _reviewed(prod)
        assert vl.apply(TID, prod)["ticked"]
        _git(prod, "add", "-A")
        _git(prod, "commit", "-q", "-m", "ticked", env=_ident("Someone"))
        _task_commit(prod, {"notes.md": "notes v2\n"}, f"{TID}: change after review")
        monkeypatch.setenv("PROJECT_ROOT", str(prod))
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            assert vl._cli(["apply", TID]) == 0
        lines = [ln for ln in err.getvalue().splitlines() if ln.startswith("WITHDRAWN")]
        assert len(lines) == 1, err.getvalue()
        assert TID in lines[0] and "AC1" in lines[0] and "stale-review" in lines[0]
        assert vl._read(vl.VERDICTS, prod)[-1]["id"] in lines[0]
        assert '"withdrawn": [{' in out.getvalue()

    def test_control_no_withdrawal_prints_nothing(self, prod, monkeypatch):
        _reviewed(prod)
        monkeypatch.setenv("PROJECT_ROOT", str(prod))
        err = io.StringIO()
        with redirect_stdout(io.StringIO()), redirect_stderr(err):
            assert vl._cli(["apply", TID]) == 0
        assert "WITHDRAWN" not in err.getvalue()
