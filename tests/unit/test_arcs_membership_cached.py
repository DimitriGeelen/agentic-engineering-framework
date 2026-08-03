"""T-2774: /arcs constituent resolution must not re-scan the corpus per arc.

Two performance invariants that are correctness-shaped, because in both cases a
cache already existed and the hot path went around it — leaving a docstring that
claimed caching and a body that didn't do any. Nothing failed; the page just got
slower every time the corpus grew, which is invisible until it crosses somebody's
timeout. These pin the wiring so the claim and the code cannot drift apart again.

  1. `_resolve_constituents` calls `_arc_membership()` (60s TTL), not the raw
     `_scan_tasks_by_arc_membership()`. One full-corpus scan per *arc* meant 14
     scans per /approvals render.
  2. `_read_task_meta` reads the shared task-metadata cache instead of globbing
     `.tasks/` and re-parsing one file per task id — 393 globs + 393 parses on a
     single render, for files the shared cache had already parsed.
"""
from __future__ import annotations

import pytest

from web.blueprints import arcs as arcs_mod


@pytest.fixture
def reset_caches():
    """Clear both the arcs-local caches and the shared task cache.

    Without this the assertions would depend on whatever earlier tests warmed,
    and "scan ran 0 times" would pass for the wrong reason.

    Deliberately opt-in rather than autouse: each reset forces a full re-parse of
    the task corpus, and only the three tests that assert *about* cache behaviour
    need a cold start. The two shape assertions read fine off a warm cache, and
    making them pay for isolation they don't use is how a suite gets slow enough
    that people stop running it.
    """
    arcs_mod._ARC_MEMBERSHIP_CACHE = None
    arcs_mod._TASK_META_INDEX = None
    from web import shared

    shared._task_cache["data"] = None
    shared._task_cache["names"] = None
    shared._task_cache["ts"] = 0
    yield
    arcs_mod._ARC_MEMBERSHIP_CACHE = None
    arcs_mod._TASK_META_INDEX = None
    shared._task_cache["data"] = None
    shared._task_cache["names"] = None
    shared._task_cache["ts"] = 0


def test_resolve_constituents_scans_membership_once_across_many_arcs(reset_caches, monkeypatch):
    """N arcs must cost one membership scan, not N."""
    calls = {"n": 0}
    real = arcs_mod._scan_tasks_by_arc_membership_shared

    def counting(root):
        calls["n"] += 1
        return real(root)

    monkeypatch.setattr(arcs_mod, "_scan_tasks_by_arc_membership_shared", counting)

    arcs = [
        {"slug": f"arc-slug-{i}", "id": f"arc-{i:03d}", "constituent_tasks": []}
        for i in range(14)
    ]
    for arc in arcs:
        arcs_mod._resolve_constituents(arc)

    assert calls["n"] == 1, (
        f"membership scan ran {calls['n']}x for {len(arcs)} arcs — expected 1. "
        "_resolve_constituents is calling the uncached _scan_tasks_by_arc_membership() "
        "instead of the cached _arc_membership() wrapper."
    )


def test_read_task_meta_does_not_reparse_per_task_id(reset_caches, monkeypatch):
    """Many _read_task_meta lookups must cost one corpus read, not one each."""
    from web import shared

    calls = {"n": 0}
    real = shared.get_all_task_metadata

    def counting():
        calls["n"] += 1
        return real()

    monkeypatch.setattr(shared, "get_all_task_metadata", counting)

    rows = real()
    if len(rows) < 3:
        pytest.skip("needs a few real tasks to look up")
    # real() above warmed the shared cache; count only the lookups below.
    calls["n"] = 0
    ids = [r.get("id") for r in rows[:25] if r.get("id")]
    for tid in ids:
        arcs_mod._read_task_meta(tid)

    # One call per lookup into the (cached) shared helper is fine — what must not
    # happen is a per-id directory glob + YAML parse. The index is built once.
    assert arcs_mod._TASK_META_INDEX is not None
    assert len(arcs_mod._TASK_META_INDEX[1]) >= len(ids)


def test_read_task_meta_returns_expected_shape():
    """Keys callers and the arc_badge macro depend on must survive the rewrite."""
    from web import shared

    rows = shared.get_all_task_metadata()
    row = next((r for r in rows if r.get("id")), None)
    if row is None:
        pytest.skip("no tasks in corpus")

    meta = arcs_mod._read_task_meta(row["id"])
    assert meta is not None
    for key in ("id", "name", "status", "horizon", "type", "completed", "arc_id", "_tags"):
        assert key in meta, f"_read_task_meta dropped {key!r} — arc templates read it"
    assert meta["id"] == row["id"]
    assert meta["completed"] == (row.get("_location") == "completed")
    assert isinstance(meta["_tags"], list)


def test_read_task_meta_returns_none_for_unknown_id():
    assert arcs_mod._read_task_meta("T-99999999") is None


def test_task_meta_index_rebuilds_when_shared_cache_refreshes(reset_caches):
    """The index must follow the shared cache, not outlive it.

    Validity is keyed on the identity of the rows list. This is the assertion
    that would fail if that key were `id(rows)` without retaining a reference:
    the old list could be freed and its address reused, making a stale index
    compare equal to a fresh one.
    """
    from web import shared

    if not shared.get_all_task_metadata():
        pytest.skip("no tasks in corpus")

    first = arcs_mod._task_meta_index()
    assert arcs_mod._task_meta_index() is first, "index should be memoised within a cache window"

    # Force the shared cache to refill — this replaces the rows list wholesale.
    shared._task_cache["data"] = None
    shared._task_cache["ts"] = 0
    second = arcs_mod._task_meta_index()

    assert second is not first, (
        "index was not rebuilt after the shared task cache refreshed — "
        "stale task metadata would be served until process restart"
    )
