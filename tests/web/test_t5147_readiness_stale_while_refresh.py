"""T-5147: after a review-ledger write the board serves the last known WAITING and refreshes it
in the background; it never serves a stale READY, and exact callers always recompute.

Before: any write to .context/reviews/*.jsonl moved _readiness_stamp, and the next board
request recomputed every awaiting task inline (9-22 s; independent reviewer on T-5136).
"""
import os
import sys
from pathlib import Path

import pytest

os.environ.setdefault("PROJECT_ROOT", str(Path(__file__).resolve().parents[2]))
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from web import shared  # noqa: E402


@pytest.fixture()
def rig(tmp_path, monkeypatch):
    task = tmp_path / "T-9990-x.md"
    task.write_text("---\nid: T-9990\n---\nbody\n")
    state = {"stamp": ("ledger", 1), "answer": (shared.WAITING_ON_AGENT, ("not green",)), "calls": 0}

    def fake_compute(task_id, body, root, path, stamp, used=None):
        state["calls"] += 1
        if used is not None:
            used.append(True)          # the result depends on the ledger stamp
        return state["answer"]

    monkeypatch.setattr(shared, "_compute_readiness", fake_compute)
    monkeypatch.setattr(shared, "_readiness_stamp", lambda root: state["stamp"])
    monkeypatch.setattr(shared, "_task_git_generation", lambda root, tid: 0)
    shared._READINESS_CACHE.clear()
    shared._READINESS_REFRESH_PENDING.clear()
    yield task, state
    t = shared._READINESS_REFRESH_THREAD.get("t")
    if t is not None:
        t.join(timeout=5)
    shared._READINESS_CACHE.clear()


def _drain():
    t = shared._READINESS_REFRESH_THREAD.get("t")
    if t is not None:
        t.join(timeout=5)


def test_board_serves_last_waiting_after_a_ledger_write_and_refreshes_in_background(rig):
    task, state = rig
    assert shared.review_readiness("T-9990", "", "", task)[0] == shared.WAITING_ON_AGENT
    assert state["calls"] == 1
    # a verdict lands: the ledger stamp moves and the true answer is now READY
    state["stamp"], state["answer"] = ("ledger", 2), (shared.READY, ())
    got = shared.review_readiness("T-9990", "", "", task, allow_stale=True)
    assert got[0] == shared.WAITING_ON_AGENT          # served from cache, no inline rebuild
    _drain()
    assert state["calls"] == 2                         # the background worker recomputed once
    assert shared.review_readiness("T-9990", "", "", task, allow_stale=True)[0] == shared.READY
    assert state["calls"] == 2                         # and stored it


def test_a_stale_ready_is_never_served(rig):
    task, state = rig
    state["answer"] = (shared.READY, ())
    assert shared.review_readiness("T-9990", "", "", task)[0] == shared.READY
    state["stamp"], state["answer"] = ("ledger", 2), (shared.WAITING_ON_AGENT, ("red verdict",))
    got = shared.review_readiness("T-9990", "", "", task, allow_stale=True)
    assert got[0] == shared.WAITING_ON_AGENT           # recomputed in the call
    assert state["calls"] == 2


def test_exact_callers_recompute_after_a_ledger_write(rig):
    task, state = rig
    shared.review_readiness("T-9990", "", "", task)
    state["stamp"], state["answer"] = ("ledger", 2), (shared.READY, ())
    assert shared.review_readiness("T-9990", "", "", task)[0] == shared.READY
    assert state["calls"] == 2


def test_task_file_change_is_never_served_stale(rig):
    task, state = rig
    shared.review_readiness("T-9990", "", "", task)
    st = task.stat()
    task.write_text("---\nid: T-9990\n---\nchanged\n")
    os.utime(task, ns=(st.st_atime_ns, st.st_mtime_ns + 5_000_000_000))
    state["answer"] = (shared.READY, ())
    assert shared.review_readiness("T-9990", "", "", task, allow_stale=True)[0] == shared.READY
    assert state["calls"] == 2


def test_board_path_asks_for_stale(monkeypatch):
    seen = {}
    monkeypatch.setattr(shared, "task_review_state",
                        lambda path, allow_stale=False: seen.setdefault("a", allow_stale) and (None, [], 0) or (None, [], 0))
    shared.board_awaiting_reason({"_path": "/x/T-1-y.md", "_location": "active"})
    assert seen["a"] is True
