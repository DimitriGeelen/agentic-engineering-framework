"""T-5195: single-flight review readiness, and the approvals page on the T-5147 stale path.

* Concurrent callers for one task compute its readiness once (exact callers wait for the
  in-flight result; allow_stale callers with a cached WAITING are served it).
* A cached READY whose key moved is never served stale.
* The approvals context reports how many entries were served stale.

Everything runs against a throwaway project in tmp_path with a counting stand-in for
``_compute_readiness``; nothing touches the real .context/reviews.
"""
import os
import sys
import threading
import time
from pathlib import Path

import pytest

os.environ.setdefault("PROJECT_ROOT", str(Path(__file__).resolve().parents[2]))
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from web import shared  # noqa: E402
from web.app import app  # noqa: E402  (imported before PROJECT_ROOT is patched)
from web.blueprints import approvals as ap  # noqa: E402

BODY = """## Acceptance Criteria

### Agent
- [x] done

### Human
- [ ] [REVIEW] looks right
  **Steps:** 1. look
  **Expected:** fine
  **If not:** say so
"""


@pytest.fixture()
def rig(tmp_path, monkeypatch):
    (tmp_path / ".context" / "reviews").mkdir(parents=True)
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    state = {"answer": {}, "calls": {}, "delay": 0.0, "key": 0}
    lock = threading.Lock()

    def fake_compute(task_id, body, root, path, stamp, used=None):
        with lock:
            state["calls"][task_id] = state["calls"].get(task_id, 0) + 1
        time.sleep(state["delay"])
        if used is not None:
            used.append(True)
        ans = state["answer"].get(task_id, shared.READY)
        return ans, (() if ans == shared.READY else ("not green",))

    monkeypatch.setattr(shared, "PROJECT_ROOT", str(tmp_path))
    monkeypatch.setattr(shared, "_compute_readiness", fake_compute)
    monkeypatch.setattr(shared, "_git_generation", lambda root: (0, 0))
    monkeypatch.setattr(shared, "_task_git_generation", lambda root, tid: 0)
    # the ledger part of the key: bump state["key"] to invalidate every task at once
    monkeypatch.setattr(shared, "_readiness_task_key",
                        lambda root, tid, stamp: ("k", state["key"]))
    shared._READINESS_CACHE.clear()
    shared._READINESS_INFLIGHT.clear()

    def make(tid):
        p = tmp_path / ".tasks" / "active" / f"{tid}-x.md"
        p.write_text(f"---\nid: {tid}\nstatus: work-completed\nworkflow_type: build\n---\n{BODY}")
        return p

    yield state, make
    t = shared._READINESS_REFRESH_THREAD.get("t")
    if t is not None:
        t.join(timeout=10)
    shared._READINESS_CACHE.clear()
    shared._READINESS_INFLIGHT.clear()


def _run(n, fn):
    out, errs = [None] * n, []
    barrier = threading.Barrier(n)

    def go(i):
        try:
            barrier.wait()
            out[i] = fn()
        except Exception as e:  # pragma: no cover - surfaced below
            errs.append(e)

    ts = [threading.Thread(target=go, args=(i,)) for i in range(n)]
    for t in ts:
        t.start()
    for t in ts:
        t.join(timeout=20)
    assert not errs
    return out


def _join_refresh():
    t = shared._READINESS_REFRESH_THREAD.get("t")
    if t is not None:
        t.join(timeout=10)


def test_concurrent_exact_calls_compute_once(rig):
    state, make = rig
    p = make("T-9101")
    state["delay"] = 0.3
    out = _run(8, lambda: shared.review_readiness("T-9101", "", "", p))
    assert state["calls"]["T-9101"] == 1
    assert all(o == (shared.READY, []) for o in out)
    assert not shared._READINESS_INFLIGHT


def test_concurrent_stale_callers_served_waiting_and_refreshed_once(rig):
    state, make = rig
    p = make("T-9102")
    state["answer"]["T-9102"] = shared.WAITING_ON_AGENT
    shared.review_readiness("T-9102", "", "", p)        # warm: WAITING cached
    assert state["calls"]["T-9102"] == 1
    state["key"] += 1                                    # every key moves
    state["answer"]["T-9102"] = shared.READY
    state["delay"] = 0.2
    stale: set = set()
    out = _run(6, lambda: shared.review_readiness("T-9102", "", "", p,
                                                  allow_stale=True, stale_out=stale))
    assert all(o[0] == shared.WAITING_ON_AGENT for o in out)   # stale WAITING served
    assert stale == {"T-9102"}
    _join_refresh()
    assert state["calls"]["T-9102"] == 2                 # one background refresh, no inline
    assert shared.review_readiness("T-9102", "", "", p,
                                   allow_stale=True) == (shared.READY, [])


def test_stale_ready_is_never_served(rig):
    state, make = rig
    p = make("T-9103")
    assert shared.review_readiness("T-9103", "", "", p)[0] == shared.READY
    state["key"] += 1
    state["answer"]["T-9103"] = shared.WAITING_ON_AGENT
    state["delay"] = 0.2
    stale: set = set()
    out = _run(5, lambda: shared.review_readiness("T-9103", "", "", p,
                                                  allow_stale=True, stale_out=stale))
    assert all(o[0] == shared.WAITING_ON_AGENT for o in out)   # recomputed, not the old READY
    assert state["calls"]["T-9103"] == 2                 # once at warm, once for 5 callers
    assert stale == set()


def test_wait_times_out_and_computes_itself(rig, monkeypatch):
    state, make = rig
    p = make("T-9104")
    monkeypatch.setattr(shared, "_READINESS_INFLIGHT_WAIT_S", 0.05)
    hung = threading.Event()
    shared._READINESS_INFLIGHT[str(p)] = hung           # a computation that never finishes
    t0 = time.time()
    assert shared.review_readiness("T-9104", "", "", p) == (shared.READY, [])
    assert time.time() - t0 < 2
    assert state["calls"]["T-9104"] == 1
    assert shared._READINESS_INFLIGHT.get(str(p)) is hung   # not the waiter's to remove


def test_review_queue_groups_default_is_exact(rig):
    state, make = rig
    p = make("T-9105")
    state["answer"]["T-9105"] = shared.WAITING_ON_AGENT
    entries = [(p, p.read_text())]
    assert shared.review_queue_groups(entries=entries)["waiting"] == ["T-9105"]
    state["key"] += 1
    state["answer"]["T-9105"] = shared.READY
    stale: set = set()
    assert shared.review_queue_groups(entries=entries, stale_out=stale)["ready"] == ["T-9105"]
    assert stale == set()


def test_approvals_context_reports_stale_count(rig, monkeypatch):
    state, make = rig
    ids = ("T-9201", "T-9202", "T-9203")
    paths = {tid: make(tid) for tid in ids}
    state["answer"] = {"T-9201": shared.WAITING_ON_AGENT, "T-9202": shared.WAITING_ON_AGENT,
                       "T-9203": shared.READY}
    meta = [{"id": tid, "name": tid, "status": "work-completed", "workflow_type": "build",
             "owner": "human", "_location": "active", "_path": str(paths[tid])} for tid in ids]
    monkeypatch.setattr(ap, "get_all_task_metadata", lambda *a, **k: meta)
    for name, val in (("_load_pending_approvals", []), ("_load_resolved_approvals", []),
                      ("_load_pending_go_decisions", []), ("_load_decided_unclosed", []),
                      ("_load_stale_keystones", []), ("_count_deferred_inceptions", 0),
                      ("_load_paused_dispatches", []), ("_load_close_ready_arcs", []),
                      ("_load_batch_ready_tasks", []),
                      ("_load_waiting_messages", {"items": [], "error": None, "warn_hours": 24}),
                      ("_halt_state", {"halted": False})):
        monkeypatch.setattr(ap, name, lambda *a, _v=val, **k: _v)
    import web.blueprints.bvp as bvp
    monkeypatch.setattr(bvp, "_load_proposals", lambda *a, **k: [])

    with app.test_request_context("/approvals"):
        ctx = ap._build_approvals_context()
    assert ctx["refreshing_count"] == 0                  # cold: computed, nothing stale
    assert {t["task_id"] if "task_id" in t else t.get("id") for t in ctx["pending_acs"]} == {"T-9203"}

    state["key"] += 1                                    # invalidate every task
    state["answer"] = {tid: shared.READY for tid in ids}
    with app.test_request_context("/approvals"):
        ctx = ap._build_approvals_context()
        html = __import__("flask").render_template("_approvals_content.html", **ctx)
    assert ctx["refreshing_count"] == 2                  # the two stale WAITINGs
    assert "2 entries are being refreshed; reload in a minute." in html
    # the stale READY was recomputed inline (still READY); the two WAITINGs may already
    # have been refreshed by the background worker before their card was built
    assert "T-9203" in {t["task_id"] if "task_id" in t else t.get("id") for t in ctx["pending_acs"]}
    _join_refresh()
    with app.test_request_context("/approvals"):
        ctx = ap._build_approvals_context()
    assert ctx["refreshing_count"] == 0
    assert len(ctx["pending_acs"]) == 3
