"""T-3860 — the hourly reindex must never fill a disk or orphan its scratch.

Origin: ring20-dashboard's production root disk hit 100% on 2026-10-04 when the
hourly `fw index reindex` (seeded to every consumer by T-3783) copied a 1.5 GB
index with no free-space check, and left a 464 MB orphan `*.reindex.<pid>.tmp`
when the copy failed. These tests pin, on fixtures (never the real index):

  REFUSE   — short of index size + max(20%, 500 MB) free, the run raises
             InsufficientDiskSpace before writing a byte; the live index is
             byte-identical and the lock is released.
  CLEAN    — exception, ENOSPC, "disk is full" and SIGTERM all leave no
             `.reindex.<pid>.tmp`/`.building`; a half-written copy is never
             parked for resume.
  SWEEP    — scratch owned by a dead pid is removed at the start of a run and
             reported; a live pid's scratch is left alone.
  HEALTH   — lib/vector_index_health.py WARNs on orphans (with sizes) and on
             free space below what the next reindex needs.
"""

import errno
import os
import signal
import sqlite3
import struct
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "lib"))

from web import embeddings as E  # noqa: E402
from web import search_utils as SU  # noqa: E402
import vector_index_health as V  # noqa: E402

PLENTY = 10 * 1024 ** 4  # 10 TB


def _fake_embed(texts, host=None):
    return [struct.pack(f"{E.EMBEDDING_DIM}f", *([0.01] * E.EMBEDDING_DIM))
            for _ in texts]


@pytest.fixture
def project(tmp_path, monkeypatch):
    monkeypatch.setattr(SU, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(E, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(E, "DB_PATH", tmp_path / "vec.db")
    monkeypatch.setattr(E, "_db", None)
    monkeypatch.setattr(E, "_db_opened_at", 0.0, raising=False)
    monkeypatch.setattr(E, "_embed", _fake_embed)
    monkeypatch.setattr(E, "_disk_free", lambda p: PLENTY)
    (tmp_path / "alpha.md").write_text("# Alpha\n\nOriginal alpha content.\n")
    (tmp_path / "beta.md").write_text("# Beta\n\nOriginal beta content.\n")
    return tmp_path


def _scratch(project):
    return sorted(p.name for p in project.iterdir()
                  if ".reindex." in p.name and ".tmp" in p.name or "building" in p.name)


def _resume(project):
    return E.DB_PATH.with_suffix(E.DB_PATH.suffix + ".reindex.resume")


def _dead_pid():
    p = subprocess.Popen([sys.executable, "-c", "pass"])
    p.wait()
    return p.pid


# -------------------------------------------------------------------- REFUSE

def test_required_free_bytes_is_copy_plus_larger_margin():
    gb = 1024 ** 3
    assert E.required_free_bytes(10 * gb) == 10 * gb + 2 * gb          # 20% wins
    assert E.required_free_bytes(100) == 100 + E.DISK_MARGIN_MIN_BYTES  # 500 MB wins
    assert E.required_free_bytes(10 * gb, copying=False) == 2 * gb      # resume: no copy


def test_incremental_refuses_on_low_space_and_leaves_live_index_intact(project, monkeypatch):
    E.reindex_incremental()  # bootstrap
    (project / "alpha.md").write_text("# Alpha\n\nEdited.\n")
    before = E.DB_PATH.read_bytes()

    monkeypatch.setattr(E, "_disk_free", lambda p: 1234)
    with pytest.raises(E.InsufficientDiskSpace) as ei:
        E.reindex_incremental()
    msg = str(ei.value)
    assert "need" in msg and "1234" in msg and "\n" not in msg
    assert E.DB_PATH.read_bytes() == before
    assert _scratch(project) == [] and not _resume(project).exists()

    # Lock released: with space back, the next run goes through.
    monkeypatch.setattr(E, "_disk_free", lambda p: PLENTY)
    assert E.reindex_incremental()["mode"] == "incremental"


def test_build_index_refuses_on_low_space_without_writing(project, monkeypatch):
    monkeypatch.setattr(E, "_disk_free", lambda p: 1)
    with pytest.raises(E.InsufficientDiskSpace):
        E.reindex_incremental()  # bootstrap path -> build_index
    assert not E.DB_PATH.exists()
    assert _scratch(project) == []


def test_resume_needs_only_the_margin(project, monkeypatch):
    E.reindex_incremental()
    size = E.DB_PATH.stat().st_size
    # Park something resumable: a consistent copy with file_state.
    import shutil
    shutil.copy2(E.DB_PATH, _resume(project))
    # Enough for the margin, not for a copy.
    monkeypatch.setattr(E, "_disk_free", lambda p: E.required_free_bytes(size, copying=False))
    assert E.reindex_incremental()["mode"] == "incremental"


# --------------------------------------------------------------------- CLEAN

def test_enospc_mid_copy_leaves_no_scratch_and_no_resume(project, monkeypatch):
    E.reindex_incremental()
    before = E.DB_PATH.read_bytes()

    def partial_copy(src, dst, **kw):
        Path(dst).write_bytes(b"half a database")
        raise OSError(errno.ENOSPC, "No space left on device")

    monkeypatch.setattr(E.shutil, "copy2", partial_copy)
    with pytest.raises(OSError):
        E.reindex_incremental()
    assert _scratch(project) == []
    assert not _resume(project).exists(), "a half-written copy was parked for resume"
    assert E.DB_PATH.read_bytes() == before


def test_disk_full_mid_embed_deletes_scratch_instead_of_parking(project, monkeypatch):
    E.reindex_incremental()
    (project / "alpha.md").write_text("# Alpha\n\nEdited.\n")

    def full(texts, host=None):
        raise sqlite3.OperationalError("database or disk is full")

    monkeypatch.setattr(E, "_embed", full)
    with pytest.raises(sqlite3.OperationalError):
        E.reindex_incremental()
    assert _scratch(project) == []
    assert not _resume(project).exists(), "parking on a full disk keeps it full"


def test_ordinary_exception_leaves_no_tmp(project, monkeypatch):
    E.reindex_incremental()
    (project / "alpha.md").write_text("# Alpha\n\nEdited.\n")

    def boom(texts, host=None):
        raise RuntimeError("embed host went away")

    monkeypatch.setattr(E, "_embed", boom)
    with pytest.raises(RuntimeError):
        E.reindex_incremental()
    assert _scratch(project) == []  # parked as .reindex.resume (OBS-258), not orphaned


def test_sigterm_mid_run_cleans_up_and_restores_handler(project, monkeypatch):
    E.reindex_incremental()
    (project / "alpha.md").write_text("# Alpha\n\nEdited.\n")
    before_handler = signal.getsignal(signal.SIGTERM)
    before = E.DB_PATH.read_bytes()

    def killed(texts, host=None):
        os.kill(os.getpid(), signal.SIGTERM)
        return _fake_embed(texts)

    monkeypatch.setattr(E, "_embed", killed)
    with pytest.raises(E.ReindexInterrupted):
        E.reindex_incremental()
    assert _scratch(project) == []
    assert E.DB_PATH.read_bytes() == before
    assert signal.getsignal(signal.SIGTERM) == before_handler


def test_sigterm_mid_copy_never_parks_the_partial_copy(project, monkeypatch):
    E.reindex_incremental()

    def interrupted_copy(src, dst, **kw):
        Path(dst).write_bytes(b"half a database")
        os.kill(os.getpid(), signal.SIGTERM)

    monkeypatch.setattr(E.shutil, "copy2", interrupted_copy)
    with pytest.raises(E.ReindexInterrupted):
        E.reindex_incremental()
    assert _scratch(project) == []
    assert not _resume(project).exists()


def test_sigterm_mid_full_build_removes_building(project, monkeypatch):
    def killed(texts, host=None):
        os.kill(os.getpid(), signal.SIGTERM)
        return _fake_embed(texts)

    monkeypatch.setattr(E, "_embed", killed)
    with pytest.raises(E.ReindexInterrupted):
        E.build_index()
    assert _scratch(project) == []
    assert not E.DB_PATH.exists()


def test_build_index_refuses_while_reindex_lock_is_held(project):
    import fcntl
    fd = os.open(str(E._lock_path()), os.O_CREAT | os.O_RDWR, 0o644)
    fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    try:
        with pytest.raises(E.IndexBusy):
            E.build_index()
        assert E.reindex_incremental()["mode"] == "skipped-locked"
    finally:
        fcntl.flock(fd, fcntl.LOCK_UN)
        os.close(fd)


# --------------------------------------------------------------------- SWEEP

def test_dead_pid_scratch_is_swept_and_reported_live_pid_kept(project):
    E.reindex_incremental()
    dead = _dead_pid()
    live = os.getppid()
    orphan_tmp = project / f"vec.db.reindex.{dead}.tmp"
    orphan_bld = project / f"vec.db.{dead}.building"
    legacy_bld = project / "vec.db.building"
    live_tmp = project / f"vec.db.reindex.{live}.tmp"
    for p in (orphan_tmp, orphan_bld, legacy_bld, live_tmp):
        p.write_bytes(b"x" * 100)

    stats = E.reindex_incremental()
    swept = {s["path"] for s in stats["swept"]}
    assert swept == {orphan_tmp.name, orphan_bld.name, legacy_bld.name}
    assert all(s["bytes"] == 100 for s in stats["swept"])
    assert not orphan_tmp.exists() and not orphan_bld.exists() and not legacy_bld.exists()
    assert live_tmp.exists(), "a live process's scratch was deleted"


def test_build_index_sweeps_too(project):
    dead = _dead_pid()
    orphan = project / f"vec.db.reindex.{dead}.tmp"
    orphan.write_bytes(b"x")
    stats = E.build_index()
    assert [s["path"] for s in stats["swept"]] == [orphan.name]


# -------------------------------------------------------------------- HEALTH

def test_health_disk_ok_when_clean(project, monkeypatch):
    E.reindex_incremental()
    monkeypatch.setattr(V, "_disk_free", lambda p: PLENTY)
    assert V.check_disk(E.DB_PATH)["verdict"] == "OK"


def test_health_disk_warns_on_orphan_with_size(project, monkeypatch):
    E.reindex_incremental()
    monkeypatch.setattr(V, "_disk_free", lambda p: PLENTY)
    (project / f"vec.db.reindex.{_dead_pid()}.tmp").write_bytes(b"x" * 4096)
    (project / f"vec.db.reindex.{os.getppid()}.tmp").write_bytes(b"x")  # live: not an orphan
    c = V.check_disk(E.DB_PATH)
    assert c["verdict"] == "WARN"
    assert "1 orphan" in c["message"] and "4.0 KB" in c["message"]


def test_health_disk_warns_on_low_space(project, monkeypatch):
    E.reindex_incremental()
    monkeypatch.setattr(V, "_disk_free", lambda p: 1024)
    c = V.check_disk(E.DB_PATH)
    assert c["verdict"] == "WARN" and "free space" in c["message"]


def test_health_mirrors_embeddings_scratch_pattern():
    for name in (".reindex.42.tmp", ".reindex.42.tmp-journal", ".42.building",
                 ".42.building.manifest.json", ".building", ".reindex.lock",
                 ".reindex.resume", ".manifest.json"):
        assert bool(V._SCRATCH_RE.match(name)) == bool(E._SCRATCH_RE.match(name)), name
