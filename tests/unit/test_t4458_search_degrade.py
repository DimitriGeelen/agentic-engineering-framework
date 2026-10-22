"""T-4458: /search must never answer with a blank HTTP 500, and one slow vector
query must not hold the request.

Origin: concurrent rebuilds of the single host-wide /tmp/fw-search-index deleted
each other's segment files (FileDoesNotExist / LockBusy), the keyword fallback hit
the same broken directory, and Flask returned 500. The vector leg had no deadline.
"""
from __future__ import annotations

import threading

import pytest

import web.search as search_mod


@pytest.fixture
def small_corpus(tmp_path, monkeypatch):
    root = tmp_path / "proj"
    root.mkdir()
    files = []
    for i in range(30):
        f = root / f"doc{i}.md"
        f.write_text(f"# Doc {i}\n\nrelease decision number {i}\n")
        files.append(f)
    idx_parent = tmp_path / "idx"
    idx_parent.mkdir()
    monkeypatch.setattr(search_mod, "PROJECT_ROOT", root)
    monkeypatch.setattr(search_mod, "collect_files", lambda: list(files))
    monkeypatch.setattr(search_mod, "INDEX_PARENT", idx_parent)
    monkeypatch.setattr(search_mod, "INDEX_DIR", None)
    monkeypatch.setattr(search_mod, "_index", None)
    monkeypatch.setattr(search_mod, "_index_built_at", 0.0)
    monkeypatch.setattr(search_mod, "_rebuilding", False)
    monkeypatch.setattr(search_mod, "_retired_dirs", [])
    return idx_parent


def test_each_build_uses_its_own_directory(small_corpus):
    search_mod.build_index()
    first = search_mod.INDEX_DIR
    search_mod.build_index()
    second = search_mod.INDEX_DIR
    assert first != second
    assert first.parent == small_corpus and second.parent == small_corpus


def test_concurrent_builds_and_searches_do_not_raise(small_corpus):
    errors = []

    def worker():
        try:
            for _ in range(3):
                search_mod.build_index()
                assert search_mod.search("release")["total_hits"] > 0
        except Exception as e:  # noqa: BLE001 — any exception is the failure
            errors.append(repr(e))

    threads = [threading.Thread(target=worker) for _ in range(6)]
    for t in threads:
        t.start()
    for t in threads:
        t.join(timeout=120)
    assert errors == []
    # retired generations are cleaned up: at most current + one retired remain
    assert len(list(small_corpus.iterdir())) <= 2


def test_stale_index_is_served_while_rebuild_runs(small_corpus, monkeypatch):
    sentinel = object()
    monkeypatch.setattr(search_mod, "_index", sentinel)
    monkeypatch.setattr(search_mod, "_index_built_at", 0.0)  # stale
    release, timer = _held_until_released()

    def slow_build():
        release.wait(120)
        return sentinel

    monkeypatch.setattr(search_mod, "_build_index_locked", slow_build)
    try:
        assert search_mod.get_index() is sentinel
        assert search_mod.get_index() is sentinel  # second caller does not start another build
        # T-4616: ordering, not wall clock — both calls returned while the
        # rebuild was still held (a blocking get_index waits for the safety timer).
        assert not release.is_set(), "get_index waited for the rebuild"
    finally:
        timer.cancel()
        release.set()


def _held_until_released(safety_seconds=60):
    """(event, started safety timer). The timer releases the event only if the
    code under test blocked on it, so `event.is_set()` after the call names a
    wait without a wall-clock budget that a loaded runner can miss (T-4616)."""
    release = threading.Event()
    timer = threading.Timer(safety_seconds, release.set)
    timer.daemon = True
    timer.start()
    return release, timer


# ── the page ────────────────────────────────────────────────────────────────

@pytest.fixture
def web_client():
    from web.app import app

    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def _boom(*a, **k):
    raise ValueError('Failed to open file for read: FileDoesNotExist("meta.json")')


def test_keyword_index_failure_renders_page_not_500(web_client, monkeypatch):
    import web.embeddings as emb

    monkeypatch.setattr(emb, "is_index_ready", lambda: False)
    monkeypatch.setattr(search_mod, "search", _boom)
    monkeypatch.setattr(search_mod, "index_stats", _boom)
    resp = web_client.get("/search?q=release+decision&mode=hybrid")
    assert resp.status_code == 200
    assert b"search-degraded-notice" in resp.data
    assert b"Keyword search is unavailable" in resp.data


def test_slow_vector_leg_degrades_to_keyword_after_deadline(web_client, monkeypatch):
    import web.blueprints.discovery as discovery
    import web.embeddings as emb

    monkeypatch.setattr(discovery, "VECTOR_DEADLINE_SECONDS", 0.3)
    monkeypatch.setattr(emb, "is_index_ready", lambda: True)
    release, timer = _held_until_released()
    monkeypatch.setattr(emb, "hybrid_search", lambda q, limit=20: (release.wait(120), {"results": []})[1])
    monkeypatch.setattr(search_mod, "search", lambda q, limit=30: {
        "query": q, "total_hits": 1,
        "categories": {"Tasks": [{"path": "kwhit-T4458.md", "title": "Keyword hit",
                                  "task_id": "", "score": 1.0, "snippet": "x"}]},
    })
    monkeypatch.setattr(search_mod, "index_stats", lambda: {"num_docs": 1})
    try:
        resp = web_client.get("/search?q=release+decision&mode=hybrid")
        answered_while_vector_held = not release.is_set()
    finally:
        timer.cancel()
        release.set()
    assert resp.status_code == 200
    # T-4616: was `elapsed < 1.5` against a 2s sleep — missed on a loaded runner.
    assert answered_while_vector_held, "/search waited for the vector leg past its deadline"
    assert b"Semantic search timed out" in resp.data
    assert b"Keyword hit" in resp.data


def test_vector_exception_degrades_with_notice(web_client, monkeypatch):
    import web.embeddings as emb

    monkeypatch.setattr(emb, "is_index_ready", lambda: True)
    monkeypatch.setattr(emb, "search", _boom)
    monkeypatch.setattr(search_mod, "search", lambda q, limit=30: {"query": q, "total_hits": 0, "categories": {}})
    monkeypatch.setattr(search_mod, "index_stats", lambda: {"num_docs": 0})
    resp = web_client.get("/search?q=release+decision&mode=semantic")
    assert resp.status_code == 200
    assert b"Semantic search failed" in resp.data


def test_startup_warmup_builds_the_keyword_index():
    from web import warmup

    assert any(p.startswith("/search?q=") and "mode=keyword" in p for p in warmup.WARM_PATHS)
