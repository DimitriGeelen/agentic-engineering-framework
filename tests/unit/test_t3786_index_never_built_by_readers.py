"""T-3786: readers of the vector index never build it, and a full build is atomic.

Origin (2026-10-04): the live 2.5 GB index became 45 KB. `_get_db()` fell through
to `build_index()` on any open/count failure, and `build_index()` unlinked the live
index first and rebuilt in place; a timed-out caller left it empty. Every test here
points the module at a temporary database — never the live index, never Ollama.
"""
import hashlib
import sqlite3

import pytest

import web.embeddings as emb


@pytest.fixture
def tmp_db(tmp_path, monkeypatch):
    db = tmp_path / "fw-vec-index.db"
    monkeypatch.setattr(emb, "DB_PATH", db)
    monkeypatch.setattr(emb, "_db", None)
    return db


def _digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def test_unopenable_index_raises_and_is_left_untouched(tmp_db):
    tmp_db.write_bytes(b"not a sqlite database " * 400)  # > 4096 bytes
    before = _digest(tmp_db)
    with pytest.raises(emb.IndexUnavailable) as e:
        emb._get_db()
    assert "fw index reindex" in str(e.value)
    assert tmp_db.exists() and _digest(tmp_db) == before


def test_empty_index_raises_and_is_left_untouched(tmp_db):
    con = sqlite3.connect(str(tmp_db))
    con.execute("CREATE TABLE documents (id INTEGER PRIMARY KEY, path TEXT)")
    con.execute("CREATE TABLE filler (x BLOB)")
    con.execute("INSERT INTO filler VALUES (?)", (b"x" * 8192,))
    con.commit()
    con.close()
    with pytest.raises(emb.IndexUnavailable):
        emb._get_db()
    # Opening may add missing schema (CREATE TABLE IF NOT EXISTS) — but nothing is
    # deleted and nothing is rebuilt: the existing data is still there.
    con = sqlite3.connect(str(tmp_db))
    try:
        assert con.execute("SELECT length(x) FROM filler").fetchone()[0] == 8192
    finally:
        con.close()


def test_missing_index_raises_without_creating_one(tmp_db):
    with pytest.raises(emb.IndexUnavailable):
        emb._get_db()
    assert not tmp_db.exists()


def test_failed_build_leaves_the_previous_index_byte_identical(tmp_db, monkeypatch):
    tmp_db.write_bytes(b"previous index " * 1000)
    before = _digest(tmp_db)

    def boom():
        raise RuntimeError("killed mid-build")

    monkeypatch.setattr(emb, "collect_files", boom)
    with pytest.raises(RuntimeError):
        emb.build_index()
    assert _digest(tmp_db) == before
    assert emb.DB_PATH == tmp_db  # the temporary path never leaks out


def test_successful_build_swaps_atomically(tmp_db, monkeypatch):
    import struct
    tmp_db.write_bytes(b"previous index " * 1000)
    before = _digest(tmp_db)
    monkeypatch.setattr(emb, "collect_files", lambda: [])
    zero = struct.pack(f"{emb.EMBEDDING_DIM}f", *([0.0] * emb.EMBEDDING_DIM))
    monkeypatch.setattr(emb, "_embed", lambda texts, host=None: [zero for _ in texts])
    stats = emb.build_index()
    assert stats["num_docs"] >= 0
    assert _digest(tmp_db) != before  # the new build replaced the old file
    assert tmp_db.exists()
    assert not tmp_db.with_name(tmp_db.name + ".building").exists()
    con = sqlite3.connect(str(tmp_db))
    try:
        assert con.execute("SELECT COUNT(*) FROM sqlite_master").fetchone()[0] > 0
    finally:
        con.close()
