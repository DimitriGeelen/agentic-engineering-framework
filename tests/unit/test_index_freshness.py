"""Index freshness is a property of the index, not of the handle — T-3012.

Slice 3 of T-3005. The defect these tests pin is the T-3004 root cause:
`_db_built_at` was stamped with `time.time()` every time `_get_db()` *reopened*
an existing database file (`web/embeddings.py:341`, pre-fix). The stamp therefore
renewed itself on every process start and on every TTL expiry, so a five-month-old
index reported itself seconds old and the staleness TTL could never fire while a
non-empty file existed.

Every test here was observed RED against the pre-fix module before the fix landed;
the two marked LOAD-BEARING are the ones that fail for the *original* reason rather
than for a renamed symbol.

`build_index` is monkeypatched to raise in every test that can reach `_get_db()`.
If a fixture ever stops satisfying the reuse branch, the fall-through would embed
the real 393k-chunk corpus — hours, inside a unit test. A loud error is the correct
outcome there, not a slow one.
"""

import sqlite3
import sys
import time
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from web import corpus_manifest as M  # noqa: E402
from web import embeddings as E  # noqa: E402

DAY = 86400.0


@pytest.fixture
def isolated(tmp_path, monkeypatch):
    """Point the module at a scratch DB and forget any cached handle."""
    db = tmp_path / "vec.db"
    monkeypatch.setattr(E, "DB_PATH", db)
    monkeypatch.setattr(E, "_db", None)
    monkeypatch.setattr(E, "_db_opened_at", 0.0, raising=False)

    def _never(*a, **k):
        raise AssertionError(
            "build_index() reached from a unit test — the reuse branch stopped "
            "being satisfied; fix the fixture rather than letting this embed the "
            "real corpus"
        )

    monkeypatch.setattr(E, "build_index", _never)
    return db


def _populate(db_path: Path, rows: int = 8) -> None:
    """A real sqlite-vec database with content, big enough for the reuse branch."""
    db = E._init_db()
    for i in range(rows):
        db.execute(
            "INSERT INTO documents (id, path, title, category, task_id, "
            "chunk_index, chunk_text) VALUES (?,?,?,?,?,?,?)",
            (i + 1, f"docs/f{i}.md", f"F{i}", "docs", "", 0, "x" * 1024),
        )
    db.commit()
    db.close()
    size = db_path.stat().st_size
    assert size > 4096, (
        f"fixture DB is {size} bytes; _get_db() only reuses files over 4096 and "
        f"would otherwise rebuild"
    )


def _manifest_aged(db_path: Path, age_seconds: float) -> None:
    m = M.build_manifest(
        num_docs=8, num_chunks=8, model="test-model", embedding_dim=768,
        max_chunk_chars=1024, embed_context_tokens=512,
        canary_token="FWCANARY-1", started_at=0.0, project_root=db_path.parent,
    )
    m["finished_at"] = time.time() - age_seconds
    M.write_manifest(db_path, m)


# --------------------------------------------------------------------------
# The freshness API itself
# --------------------------------------------------------------------------

def test_age_comes_from_the_manifest(isolated):
    _populate(isolated)
    _manifest_aged(isolated, 200 * DAY)

    f = E.index_freshness()
    assert f["source"] == "manifest"
    assert 199 * DAY < f["age_seconds"] < 201 * DAY, f


def test_falls_back_to_file_mtime_when_there_is_no_manifest(isolated):
    """Every index built before T-3011 has no manifest. mtime is a worse answer
    than the manifest — it moves on any write — but it is a real one, and the
    caller is told which it got."""
    _populate(isolated)
    old = time.time() - 40 * DAY
    import os
    os.utime(isolated, (old, old))

    f = E.index_freshness()
    assert f["source"] == "db_mtime"
    assert 39 * DAY < f["age_seconds"] < 41 * DAY, f


def test_absent_index_reports_unknown_not_zero(isolated):
    """Tri-state, same rule as corpus_health() in T-3011: no index is *unknown*.

    A 0.0 here would be indistinguishable from "built this instant" — which is
    precisely the confusion that let the frozen index look healthy.
    """
    f = E.index_freshness()
    assert f["source"] == "unknown"
    assert f["built_at"] is None
    assert f["age_seconds"] is None


def test_corrupt_manifest_degrades_to_mtime_rather_than_raising(isolated):
    _populate(isolated)
    M.manifest_path_for(isolated).write_text("{ not json")

    f = E.index_freshness()
    assert f["source"] == "db_mtime"
    assert f["age_seconds"] is not None


def test_manifest_without_a_usable_finished_at_degrades_to_mtime(isolated):
    _populate(isolated)
    _manifest_aged(isolated, 5 * DAY)
    import json
    p = M.manifest_path_for(isolated)
    data = json.loads(p.read_text())
    data["finished_at"] = "yesterday"
    p.write_text(json.dumps(data))

    assert E.index_freshness()["source"] == "db_mtime"


# --------------------------------------------------------------------------
# LOAD-BEARING: the original defect
# --------------------------------------------------------------------------

def test_reopening_the_handle_does_not_advance_the_reported_build_time(isolated):
    """LOAD-BEARING. This is T-3004 in miniature.

    Pre-fix, `index_stats()["built_at"]` was `_db_built_at`, restamped inside
    `_get_db()`'s reuse branch. Dropping the cached handle and asking again
    therefore reported a *newer* build time for a database nobody rebuilt.
    """
    _populate(isolated)
    _manifest_aged(isolated, 200 * DAY)

    first = E.index_stats()["built_at"]
    E._db = None                       # next call re-opens the same file
    time.sleep(0.01)
    second = E.index_stats()["built_at"]

    assert first == second, (
        "reported build time advanced without a rebuild — the freshness clock "
        "is still being restamped on handle reuse"
    )
    assert time.time() - second > 199 * DAY, (
        "a 200-day-old index reported itself fresh"
    )


def test_stats_separate_index_age_from_handle_open_time(isolated):
    """LOAD-BEARING. Both numbers are legitimate; conflating them was the bug.

    The handle-open time is real and useful (it says how long this process has
    held its connection). It just is not, and never was, the index's age.
    """
    _populate(isolated)
    _manifest_aged(isolated, 200 * DAY)

    s = E.index_stats()
    assert s["freshness_source"] == "manifest"
    assert 199 * DAY < s["index_age_seconds"] < 201 * DAY
    assert s["handle_opened_at"] >= time.time() - 60, (
        "handle_opened_at should be ~now — this process just opened it"
    )
    assert s["index_built_at"] < s["handle_opened_at"] - 199 * DAY, (
        "index_built_at and handle_opened_at collapsed to the same value"
    )


def test_the_ttl_governs_the_connection_not_the_index(isolated, monkeypatch):
    """The TTL expiring must not, by itself, change what freshness reports.

    Pre-fix, crossing STALE_SECONDS re-entered the reuse branch and restamped —
    so the one mechanism named "stale" made the index look newer.
    """
    _populate(isolated)
    _manifest_aged(isolated, 200 * DAY)

    before = E.index_freshness()["built_at"]
    E._db_opened_at = time.time() - (E.STALE_SECONDS + 1)   # force TTL expiry
    E._get_db()
    after = E.index_freshness()["built_at"]

    assert before == after


def test_the_handle_clock_is_not_named_a_build_clock(isolated):
    """The old name is the bug in one word. Kept as a rename tripwire so a future
    revert restores the misnomer loudly rather than quietly."""
    assert not hasattr(E, "_db_built_at"), (
        "_db_built_at is back — it records handle-open time, so the name asserts "
        "something false; use _db_opened_at"
    )
    assert hasattr(E, "_db_opened_at")


def test_freshness_never_raises_on_an_unreadable_db(isolated, monkeypatch):
    """A health primitive that throws reports nothing, and gets swallowed by the
    same `2>/dev/null` that hid the original outage (T-3011 rule, applied here)."""
    _populate(isolated)

    def boom(*a, **k):
        raise OSError("disk gone")

    monkeypatch.setattr(Path, "stat", boom)
    f = E.index_freshness()
    assert f["source"] == "unknown"


def test_populated_fixture_is_actually_reused_not_rebuilt(isolated):
    """Guards the guard: if this fails, every test above was measuring nothing
    because `build_index` (patched to raise) would have fired instead."""
    _populate(isolated)
    db = E._get_db()
    assert isinstance(db, sqlite3.Connection)
    assert db.execute("SELECT COUNT(*) FROM documents").fetchone()[0] == 8
