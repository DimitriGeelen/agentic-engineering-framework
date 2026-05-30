"""Unit tests for web.shared.mtime_cached_get (T-2109).

Pins the helper-vs-consumer contract per L-362: the helper promoted from 5
ad-hoc cache sites (T-1954, T-2102, T-2106, T-2107, T-2108) must behave
identically to what those sites did inline:

  (a) cold call → parse_fn runs, result cached
  (b) warm call, mtime unchanged → parse_fn does NOT run
  (c) file touched (mtime bumped) → parse_fn re-runs, cache updated
  (d) path.stat() raises OSError → default returned, parse_fn NOT called

Each test is isolated to its own cache dict so the assertions are
unambiguous about which path is exercised. A new consumer that wants to
adopt the helper should be able to read these tests as the executable spec.
"""
from __future__ import annotations

import os
from pathlib import Path
from typing import Any

import pytest

from web.shared import mtime_cached_get


@pytest.fixture
def tmp_file(tmp_path: Path) -> Path:
    """A tiny file with known content for cache-hit tests."""
    p = tmp_path / "demo.txt"
    p.write_text("alpha\n")
    return p


def test_cold_call_invokes_parse_fn(tmp_file: Path) -> None:
    """First call with empty cache must invoke parse_fn and store the result."""
    cache: dict[str, tuple[int, str]] = {}
    calls: list[Path] = []

    def parse(p: Path) -> str:
        calls.append(p)
        return p.read_text().strip()

    result = mtime_cached_get(tmp_file, parse, cache, default="")
    assert result == "alpha"
    assert calls == [tmp_file]
    assert str(tmp_file) in cache
    assert cache[str(tmp_file)][1] == "alpha"


def test_warm_call_same_mtime_does_not_re_parse(tmp_file: Path) -> None:
    """Second call with unchanged mtime returns cached value without parse_fn."""
    cache: dict[str, tuple[int, str]] = {}
    calls: list[Path] = []

    def parse(p: Path) -> str:
        calls.append(p)
        return p.read_text().strip()

    first = mtime_cached_get(tmp_file, parse, cache, default="")
    second = mtime_cached_get(tmp_file, parse, cache, default="")

    assert first == second == "alpha"
    # parse_fn called exactly once across the two reads — the canonical
    # "warm cache" guarantee the 5 origin sites relied on.
    assert len(calls) == 1


def test_file_touched_re_parses(tmp_file: Path) -> None:
    """Bumping mtime invalidates the cache entry and forces a fresh parse."""
    cache: dict[str, tuple[int, str]] = {}
    calls: list[Path] = []

    def parse(p: Path) -> str:
        calls.append(p)
        return p.read_text().strip()

    first = mtime_cached_get(tmp_file, parse, cache, default="")
    assert first == "alpha"

    # Rewrite contents and bump mtime by 1 second. Some filesystems carry
    # nanosecond resolution but stat granularity can be coarse, so we
    # explicitly utime to guarantee a different mtime_ns.
    tmp_file.write_text("beta\n")
    new_mtime = tmp_file.stat().st_mtime_ns + 10_000_000  # +10ms, well past any granularity
    os.utime(tmp_file, ns=(new_mtime, new_mtime))

    second = mtime_cached_get(tmp_file, parse, cache, default="")
    assert second == "beta"
    assert len(calls) == 2  # cold + after-touch re-parse
    assert cache[str(tmp_file)][1] == "beta"


def test_missing_file_returns_default_without_parse(tmp_path: Path) -> None:
    """Stat OSError on a missing file returns default and does NOT call parse_fn.

    Mirrors all 5 origin sites: a missing file is "no data", not a parse error,
    and parse_fn must not run on a path that doesn't exist (the sites would
    otherwise need their own try/except around path.read_text()).
    """
    missing = tmp_path / "does-not-exist.txt"
    cache: dict[str, tuple[int, Any]] = {}
    calls: list[Path] = []

    def parse(p: Path) -> str:
        calls.append(p)
        return "SHOULD-NOT-RUN"

    result = mtime_cached_get(missing, parse, cache, default="FALLBACK")
    assert result == "FALLBACK"
    assert calls == []  # parse_fn never invoked
    assert str(missing) not in cache  # no cache write on stat failure


def test_default_typed_to_consumer(tmp_path: Path) -> None:
    """Default may be any T — list, dict, None, tuple — matching consumer shapes.

    The 5 origin sites use {None, "", ({}, ""), [], None} respectively;
    the helper must not force a uniform default type.
    """
    missing = tmp_path / "missing.yaml"

    # Origin: search_utils.py:_TAG_FM_CACHE — list[str] default []
    cache_list: dict[str, tuple[int, list[str]]] = {}
    assert mtime_cached_get(missing, lambda p: ["x"], cache_list, default=[]) == []

    # Origin: timeline.py:_FM_CACHE — (dict, str) default ({}, "")
    cache_tup: dict[str, tuple[int, tuple[dict, str]]] = {}
    assert mtime_cached_get(missing, lambda p: ({"k": 1}, "body"), cache_tup, default=({}, "")) == ({}, "")

    # Origin: bvp.py:_FM_CACHE — dict|None default None
    cache_opt: dict[str, tuple[int, dict | None]] = {}
    assert mtime_cached_get(missing, lambda p: {}, cache_opt, default=None) is None
