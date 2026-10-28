"""T-4854: a health probe right after a (re)start must not ride the cold corpus build.

ring20-dashboard (be.46, msg 2c503ddf): the T-4363 warm-up runs on a daemon thread
after the port binds, so a request that reads the corpus during the warm-up waits on
shared._TASK_BUILD_LOCK for the cold build (12-13 s there, 54 s here). Their watchdog
probes with a 10 s timeout and restarts after two failures, so it looped.

Two small routes out, both pinned here:
  (b) /health never reads the corpus and reports the warm-up state, so a watchdog
      pointed at it gets a fast, truthful answer while the build runs;
  (a) WATCHTOWER_WARM_BEFORE_SERVE=1 (default 0) makes the serve entry points finish
      the warm-up before they serve, for a watchdog that can only probe a page.
"""
from __future__ import annotations

import threading
import time
from pathlib import Path

import pytest
from flask import Flask

import web.shared as shared
import web.warmup as warmup

ROOT = Path(__file__).resolve().parents[2]
SLOW = 1.5  # stubbed cold build, seconds


@pytest.fixture(autouse=True)
def _fresh_state(monkeypatch):
    saved = dict(warmup.WARMUP_STATE)
    warmup.WARMUP_STATE.update(state="idle", started_at=None, finished_at=None, paths={})
    monkeypatch.delenv("FW_WATCHTOWER_WARM_BEFORE_SERVE", raising=False)
    yield
    warmup.WARMUP_STATE.clear()
    warmup.WARMUP_STATE.update(saved)


@pytest.fixture
def slow_build(monkeypatch):
    """Cold task cache whose build takes SLOW seconds, behind the real build lock."""
    monkeypatch.setitem(shared._task_cache, "data", None)

    def _slow(now, sig):
        time.sleep(SLOW)
        shared._task_cache.update(data=[], sig=sig, ts=time.monotonic())
        return []

    monkeypatch.setattr(shared, "_build_task_metadata", _slow)


def _corpus_app():
    app = Flask(__name__)

    @app.route("/")
    def index():
        shared.get_all_task_metadata()
        return "ok"

    return app


def _timed_get(app, path):
    t0 = time.monotonic()
    status = app.test_client().get(path).status_code
    return status, time.monotonic() - t0


def test_reproduce_a_page_request_during_warmup_waits_for_the_cold_build(slow_build):
    app = _corpus_app()
    t = warmup.start_cache_warmup(app, paths=["/"])
    time.sleep(0.2)  # the warm-up holds the build lock now
    status, took = _timed_get(app, "/")
    t.join(10)
    assert status == 200
    assert took >= SLOW - 0.4, f"page answered in {took:.2f}s during a {SLOW}s cold build"


def test_health_answers_fast_during_warmup_and_reports_it(slow_build, monkeypatch):
    from web.app import app

    # keep the optional ollama probe out of the timing
    import sys, types
    monkeypatch.setitem(sys.modules, "ollama", types.SimpleNamespace(list=lambda: []))
    warmup.WARMUP_STATE["state"] = "warming"
    lock_held = threading.Event()

    def hold():
        with shared._TASK_BUILD_LOCK:
            lock_held.set()
            time.sleep(SLOW)

    holder = threading.Thread(target=hold, daemon=True)
    holder.start()
    lock_held.wait(5)
    t0 = time.monotonic()
    resp = app.test_client().get("/health")
    took = time.monotonic() - t0
    holder.join(10)
    assert resp.status_code == 200
    assert took < SLOW - 0.4, f"/health waited {took:.2f}s on the corpus build lock"
    assert resp.get_json()["warmup"]["state"] == "warming"


def test_warm_before_serve_is_off_by_default():
    assert warmup.warm_before_serve() is False


@pytest.mark.parametrize("val,want", [("1", True), ("0", False), ("", False), ("true", True)])
def test_warm_before_serve_env(monkeypatch, val, want):
    monkeypatch.setenv("FW_WATCHTOWER_WARM_BEFORE_SERVE", val)
    assert warmup.warm_before_serve() is want


def test_warm_before_serve_reads_framework_yaml(monkeypatch, tmp_path):
    (tmp_path / ".framework.yaml").write_text("WATCHTOWER_WARM_BEFORE_SERVE: 1\n")
    monkeypatch.setattr(warmup, "_project_root", lambda: tmp_path)
    assert warmup.warm_before_serve() is True


def test_wait_finishes_the_warmup_before_returning(slow_build):
    app = _corpus_app()
    t0 = time.monotonic()
    warmup.start_cache_warmup(app, paths=["/"], wait=True)
    assert warmup.WARMUP_STATE["state"] == "done"
    assert time.monotonic() - t0 >= SLOW - 0.4
    status, took = _timed_get(app, "/")  # the first served request is warm
    assert status == 200 and took < SLOW - 0.4


def test_serve_entry_points_honour_the_setting():
    for f in ("app.py", "wsgi.py"):
        assert "wait=warm_before_serve()" in (ROOT / "web" / f).read_text(), f


def test_setting_is_registered_and_on_the_config_page():
    assert "WATCHTOWER_WARM_BEFORE_SERVE|0|" in (ROOT / "lib" / "config.sh").read_text()
    assert '"WATCHTOWER_WARM_BEFORE_SERVE", "0"' in (
        ROOT / "web" / "blueprints" / "config.py").read_text()
