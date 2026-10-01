"""T-3627: a cold /graduation must not be able to wedge Watchtower.

2026-10-01: 59 of 91 server threads were inside `_build_application_index`, each
re-reading every task + episodic file — the index had a 60s TTL and no build lock,
so every concurrent miss rebuilt it. Every test here runs IN-PROCESS
(app.test_client / direct calls); none touches the operator's live Watchtower.
"""

import os
import sys
import threading
import time
from pathlib import Path

import pytest

os.environ.setdefault("PROJECT_ROOT", str(Path(__file__).resolve().parents[2]))

from web import shared  # noqa: E402
from web.blueprints import core, discovery  # noqa: E402

_counting = threading.local()


def _hook(event, args):
    if event == "open" and getattr(_counting, "root", None):
        p = args[0]
        if isinstance(p, (str, bytes, os.PathLike)) and os.fsdecode(p).startswith(_counting.root):
            _counting.n += 1


sys.addaudithook(_hook)


def _reads(root, fn):
    """(result, number of files under `root` opened while running fn) — this thread only."""
    _counting.root, _counting.n = str(root), 0
    try:
        return fn(), _counting.n
    finally:
        _counting.root = None


def _bump(path):
    st = path.stat()
    os.utime(path, ns=(st.st_atime_ns, st.st_mtime_ns + 5_000_000_000))


@pytest.fixture
def corpus(monkeypatch, tmp_path):
    for d in (".tasks/active", ".tasks/completed", ".context/episodic", ".context/project"):
        (tmp_path / d).mkdir(parents=True)
    (tmp_path / ".tasks/active/T-9001-a.md").write_text("---\nid: T-9001\n---\nsee L-101\n")
    (tmp_path / ".tasks/completed/T-9002-b.md").write_text("---\nid: T-9002\n---\nL-101 L-102\n")
    (tmp_path / ".context/episodic/T-9003.yaml").write_text("task_id: T-9003\nnote: L-102\n")
    (tmp_path / ".context/project/patterns.yaml").write_text("p: L-103\n")
    # Other web tests importlib.reload(web.shared), so the shared helpers that
    # discovery/core are bound to may live in an older module copy than `shared`.
    # Patch each copy through the helpers' own globals.
    copies = {id(d): d for d in (vars(shared), discovery.signature_cached.__globals__,
                                 core.mtime_cached_get.__globals__)}.values()
    for d in copies:
        monkeypatch.setitem(d, "PROJECT_ROOT", tmp_path)
        d["_SIG_CACHES"].clear()
    for mod in (discovery, core):
        monkeypatch.setattr(mod, "PROJECT_ROOT", tmp_path)
    discovery._APP_REFS_CACHE.clear()
    return tmp_path


def test_application_index_counts(corpus):
    assert discovery._build_application_index() == {"L-101": 2, "L-102": 2, "L-103": 1}


def test_warm_index_reads_no_file(corpus):
    discovery._build_application_index()
    _, n = _reads(corpus, discovery._build_application_index)
    assert n == 0


def test_index_is_change_driven_not_ttl(corpus):
    discovery._build_application_index()
    f = corpus / ".context/episodic/T-9003.yaml"
    f.write_text("task_id: T-9003\nnote: L-104\n")
    _bump(f)
    idx, n = _reads(corpus, discovery._build_application_index)
    assert idx.get("L-104") == 1 and idx["L-102"] == 1
    assert n == 1, "only the changed file is re-read"


def test_concurrent_misses_build_once(corpus, monkeypatch):
    """30 threads missing at once wait for ONE build instead of running 30."""
    calls = []
    real = discovery._scan_application_refs

    def slow():
        calls.append(1)
        time.sleep(0.5)
        return real()

    monkeypatch.setattr(discovery, "_scan_application_refs", slow)
    results = []
    threads = [threading.Thread(target=lambda: results.append(discovery._build_application_index()))
               for _ in range(30)]
    for t in threads:
        t.start()
    for t in threads:
        t.join(10)
    assert len(results) == 30 and len(calls) == 1


def test_inflight_limit_returns_503_with_retry_after():
    hold = threading.Event()
    entered = threading.Semaphore(0)

    @shared.limit_inflight(2)
    def view():
        entered.release()
        hold.wait(5)
        return "ok"

    from web.app import app
    out = []
    ts = []
    for _ in range(2):
        t = threading.Thread(target=lambda: out.append(_call(app, view)))
        t.start()
        ts.append(t)
    assert entered.acquire(timeout=5) and entered.acquire(timeout=5)
    resp = _call(app, view)
    hold.set()
    for t in ts:
        t.join(5)
    assert resp.status_code == 503 and resp.headers.get("Retry-After")
    assert out == ["ok", "ok"]


def _call(app, view):
    with app.test_request_context("/x"):
        rv = view()
        return app.make_response(rv) if not isinstance(rv, str) else rv


def test_30_cold_graduation_requests_leave_server_responsive(monkeypatch):
    """The AC scenario, in-process: 30 concurrent cold /graduation requests while
    / and a static file are fetched. Both must answer within 2s."""
    from web.app import app
    client = app.test_client()
    client.get("/")  # warm / so we measure contention, not its own cold build
    real = discovery._scan_application_refs

    def slow():
        time.sleep(3)  # a cold corpus scan, made deterministic
        return real()

    monkeypatch.setattr(discovery, "_scan_application_refs", slow)
    discovery.signature_cached.__globals__["_SIG_CACHES"].pop("graduation-app-index", None)
    codes = []
    threads = [threading.Thread(target=lambda: codes.append(app.test_client().get("/graduation").status_code))
               for _ in range(30)]
    for t in threads:
        t.start()
    time.sleep(0.3)
    t0 = time.perf_counter()
    assert app.test_client().get("/").status_code == 200
    t_root = time.perf_counter() - t0
    t0 = time.perf_counter()
    r = app.test_client().get("/static/pico.min.css")
    t_static = time.perf_counter() - t0
    r.close()
    for t in threads:
        t.join(30)
    assert t_root < 2.0, f"/ took {t_root:.2f}s under load"
    assert t_static < 2.0, f"static took {t_static:.2f}s under load"
    assert len(codes) == 30 and set(codes) <= {200, 503}
    assert codes.count(503) >= 30 - discovery.GRADUATION_INFLIGHT


def test_dashboard_arc_scan_cached(corpus):
    (corpus / ".context/arcs").mkdir(parents=True)
    core._arc_membership_index()
    _, n = _reads(corpus / ".tasks", core._arc_membership_index)
    assert n == 0


def test_project_research_headers_cached(corpus):
    core._build_project_categories()
    _, n = _reads(corpus / ".context/episodic", core._build_project_categories)
    assert n == 0
