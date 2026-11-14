"""T-5126 (1409 msg c905c099): `/` never waits for a cold parse of every session transcript.
The first call starts the parse in the background and returns None (the cockpit template
omits the tile); once the parse is done, the tile is back."""
from __future__ import annotations

import sys
import threading
import time
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_HERE))

from web.blueprints import core, costs  # noqa: E402


@pytest.fixture(autouse=True)
def _fresh(monkeypatch):
    monkeypatch.setitem(core._token_warm, "thread", None)
    monkeypatch.setitem(core._token_warm, "done", False)
    yield


def _session(total=1000):
    return {"total": total, "cache_read": total // 2, "turns": 3}


def test_a_cold_parse_does_not_block_and_the_tile_returns_once_warm(monkeypatch):
    release = threading.Event()
    calls = []

    def slow_load():
        calls.append(1)
        release.wait(10)
        return [_session(), _session(2000)]

    monkeypatch.setattr(costs, "_load_all_sessions", slow_load)
    t0 = time.monotonic()
    first = core._get_token_usage()
    assert first is None
    assert time.monotonic() - t0 < 1.0, "the first call waited for the parse"
    # a second request while still warming: still no wait, still one parse
    assert core._get_token_usage() is None
    release.set()
    core._token_warm["thread"].join(5)
    assert core._token_warm["done"] is True
    tile = core._get_token_usage()
    assert tile is not None and tile["sessions"] == 2
    assert len(calls) == 2   # the warm-up, then the (now fast) real read


def test_a_failing_parse_still_ends_the_warm_up(monkeypatch):
    def boom():
        raise RuntimeError("unreadable transcript")
    monkeypatch.setattr(costs, "_load_all_sessions", boom)
    assert core._get_token_usage() is None
    core._token_warm["thread"].join(5)
    assert core._token_warm["done"] is True
    assert core._get_token_usage() is None   # the tile is omitted, the page still renders
