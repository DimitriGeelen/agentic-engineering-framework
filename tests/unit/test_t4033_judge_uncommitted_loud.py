"""T-4033 (832 T-1114, T-310 row V-20261010-08c85aa1) — a verdict row left uncommitted by a lost
.git/index.lock race was silent.

Two legs:
  1. `_commit_rows_once` gave up after 5 tries (~5 s of sleep) while another session's commit
     held .git/index.lock; it now waits against a bounded deadline (INDEX_LOCK_WAIT_S).
  2. `fw reviewer judge` printed `unknown` and exited 0 when a seat's row was uncommitted; it now
     names the row on stderr (with the discard verb) and exits 4.
(The sanctioned discard verb itself shipped with T-3863.)
"""
from __future__ import annotations

import subprocess
import sys
import threading
import time
from pathlib import Path

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import verdict_ledger as vl  # noqa: E402
from lib.reviewer import judge_cli  # noqa: E402
import _review_runtime as rt  # noqa: E402
from _review_runtime import hermetic_review_env  # noqa: E402,F401  (autouse)
import t3580_judge_cli_test as t3580  # noqa: E402
from t3580_judge_cli_test import NOCAP, TASTE, TID, FakeWorker, _mk_task, _produce, repo  # noqa: E402,F401


# ── leg 1: index.lock wait ───────────────────────────────────────────────────

def _plain_repo(tmp_path):
    root = tmp_path / "proj"
    root.mkdir()
    for a in (["init", "-q"], ["config", "user.email", "t@t"], ["config", "user.name", "t"]):
        subprocess.run(["git", *a], cwd=root, check=True, capture_output=True)
    (root / "f").write_text("x\n")
    subprocess.run(["git", "add", "f"], cwd=root, check=True)
    subprocess.run(["git", "commit", "-qm", "init"], cwd=root, check=True)
    return root


def test_commit_outlasts_an_index_lock_held_longer_than_the_old_five_tries(tmp_path, monkeypatch):
    root = _plain_repo(tmp_path)
    (root / vl.VERDICTS).parent.mkdir(parents=True, exist_ok=True)
    (root / vl.VERDICTS).write_text('{"id": "V-1"}\n')
    lock = root / ".git" / "index.lock"
    lock.write_text("")
    hold = 7.0       # the old loop slept 0.5+1+1.5+2 = 5 s in total, then gave up
    threading.Timer(hold, lock.unlink).start()
    monkeypatch.setattr(vl, "INDEX_LOCK_WAIT_S", 30.0, raising=False)
    t0 = time.monotonic()
    sha, err = vl._commit_rows_once(root, [str(vl.VERDICTS)], "w", "T-1: reviewer verdict")
    assert err == "" and sha, err
    assert time.monotonic() - t0 >= hold - 0.5


def test_commit_gives_up_at_the_deadline_and_says_index_lock(tmp_path, monkeypatch):
    root = _plain_repo(tmp_path)
    (root / vl.VERDICTS).parent.mkdir(parents=True, exist_ok=True)
    (root / vl.VERDICTS).write_text('{"id": "V-1"}\n')
    (root / ".git" / "index.lock").write_text("")
    monkeypatch.setattr(vl, "INDEX_LOCK_WAIT_S", 1.0, raising=False)
    t0 = time.monotonic()
    sha, err = vl._commit_rows_once(root, [str(vl.VERDICTS)], "w", "T-1: reviewer verdict")
    assert sha == "" and "index.lock" in err and "stays uncommitted" in err
    assert time.monotonic() - t0 < 10


# ── leg 2: the judge says so, and fails ──────────────────────────────────────

def _no_verdict_commit(monkeypatch):
    """The worker's ledger commit loses the race: its row is appended but never committed."""
    real = t3580._git

    def git(root, *a, env=None):
        if a[:1] == ("add",) and ".context/reviews" in a:
            return
        if a[:1] == ("commit",) and any("reviewer verdict" in str(x) for x in a):
            return
        return real(root, *a, env=env)

    monkeypatch.setattr(t3580, "_git", git)


def test_judge_exits_4_and_names_an_uncommitted_row(repo, monkeypatch, capsys):
    rt.unbound_spend(monkeypatch)
    _mk_task(repo, TASTE)
    _produce(repo)
    _no_verdict_commit(monkeypatch)
    res = judge_cli.judge(TID, repo, dispatcher=FakeWorker("green"), capture=NOCAP,
                          worker_kinds={"claude"}, kind_vendors={"claude": "anthropic"})
    assert res["outcomes"] == {1: "unknown"}, res
    assert res["code"] == 4, res
    assert res["uncommitted"] and "verdict discard" in res["uncommitted"][0]
    judge_cli._print_result(res)
    err = capsys.readouterr().err
    assert "ERROR: verdict row left uncommitted" in err and "AC#1" in err


def test_control_committed_row_is_not_flagged(repo, monkeypatch):
    rt.unbound_spend(monkeypatch)
    _mk_task(repo, TASTE)
    _produce(repo)
    res = judge_cli.judge(TID, repo, dispatcher=FakeWorker("green"), capture=NOCAP,
                          worker_kinds={"claude"}, kind_vendors={"claude": "anthropic"})
    assert res["code"] == 0 and "uncommitted" not in res, res
