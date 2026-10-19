"""T-4363: Watchtower builds its cold corpus caches off the request thread.

Before the fix the first GET /approvals on a cold server built every corpus
cache on the request thread (832: 13.4 s vs 1.3 s warm; here 40.9 s vs 11.9 s),
and fw doctor's 5 s smoke probe reported the cold build as a timeout.
"""
from __future__ import annotations

import ast
import io
import json
import threading
from pathlib import Path

import pytest
from flask import Flask

import web.warmup as warmup

ROOT = Path(__file__).resolve().parents[2]


@pytest.fixture(autouse=True)
def _fresh_state():
    saved = dict(warmup.WARMUP_STATE)
    warmup.WARMUP_STATE.update(state="idle", started_at=None, finished_at=None, paths={})
    yield
    warmup.WARMUP_STATE.clear()
    warmup.WARMUP_STATE.update(saved)


def _app_with_cold_reader():
    app = Flask(__name__)
    cache: dict = {}
    seen: list = []

    @app.route("/cold")
    def cold():
        seen.append(threading.current_thread() is threading.main_thread())
        cache.setdefault("corpus", "built")
        return "ok"

    @app.route("/boom")
    def boom():
        raise RuntimeError("reader failed")

    return app, cache, seen


def test_warmup_fills_the_cache_off_the_main_thread():
    app, cache, seen = _app_with_cold_reader()
    t = warmup.start_cache_warmup(app, paths=["/cold"])
    assert t is not None and t.daemon
    t.join(10)
    assert cache == {"corpus": "built"}          # the cold build happened in the warm-up
    assert seen == [False]                         # ...and not on the main/request thread
    assert warmup.WARMUP_STATE["state"] == "done"
    assert warmup.WARMUP_STATE["paths"]["/cold"]["status"] == 200


def test_warmup_runs_once_and_survives_a_failing_page():
    app, cache, _ = _app_with_cold_reader()
    t = warmup.start_cache_warmup(app, paths=["/boom", "/cold"])
    t.join(10)
    assert cache == {"corpus": "built"}            # a failing page does not stop the rest
    assert warmup.WARMUP_STATE["state"] == "done"
    assert warmup.start_cache_warmup(app, paths=["/cold"]) is None


def test_default_paths_cover_the_pages_doctor_reported():
    for p in ("/", "/approvals", "/cron", "/tasks"):
        assert p in warmup.WARM_PATHS


def _calls_in(func_src_owner: Path, func_name: str | None) -> set[str]:
    tree = ast.parse(func_src_owner.read_text())
    scope = tree
    if func_name:
        scope = next(n for n in ast.walk(tree)
                     if isinstance(n, ast.FunctionDef) and n.name == func_name)
    return {n.func.id for n in ast.walk(scope)
            if isinstance(n, ast.Call) and isinstance(n.func, ast.Name)}


def test_serve_entry_points_start_the_warmup():
    # `python3 -m web.app` (fw serve / fw watchtower) and gunicorn's web.wsgi
    assert "start_cache_warmup" in _calls_in(ROOT / "web" / "app.py", "main")
    assert "start_cache_warmup" in _calls_in(ROOT / "web" / "wsgi.py", None)


def test_identity_reports_warmup_state():
    from web.app import app
    body = app.test_client().get("/api/_identity").get_json()
    assert body["warmup"]["state"] in ("idle", "warming", "done")


def test_smoke_probe_waits_for_a_running_warmup(monkeypatch):
    import web.smoke_test as smoke

    states = iter(["warming", "warming", "done"])

    class _Resp(io.BytesIO):
        def __enter__(self):
            return self

        def __exit__(self, *a):
            return False

    calls = []

    def fake_urlopen(url, timeout=None):
        calls.append(url)
        return _Resp(json.dumps({"warmup": {"state": next(states)}}).encode())

    monkeypatch.setattr(smoke.urllib.request, "urlopen", fake_urlopen)
    out = smoke.wait_for_warmup("http://x", limit=30, poll=0)
    assert out["state"] == "done" and len(calls) == 3


def test_smoke_probe_does_not_wait_on_a_server_without_warmup(monkeypatch):
    import web.smoke_test as smoke

    def fake_urlopen(url, timeout=None):
        raise OSError("refused")

    monkeypatch.setattr(smoke.urllib.request, "urlopen", fake_urlopen)
    assert smoke.wait_for_warmup("http://x", limit=30, poll=0)["state"] == "unknown"
