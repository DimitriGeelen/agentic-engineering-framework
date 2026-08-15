"""Incremental reindex — T-3014, slice 5 of T-3005.

build_index() is a full rebuild: 393,082 chunks, hours. A schedule that cannot
finish between firings is not a schedule (AC3), so this pins
reindex_incremental()'s three load-bearing properties:

  INCREMENTAL — only changed/added/removed files are re-embedded, not the
                whole corpus (AC3).
  ATOMIC      — a run killed mid-way leaves the previous index (and its
                manifest) exactly as it was; there is no reader-visible
                half-built state (AC4).
  FRESH       — a successful run advances index_freshness()'s reported age,
                because the manifest is written last and only after the swap
                (AC1, AC5).

Every test below was observed RED against a pre-fix `reindex_incremental`
(either absent, or without the tmp-copy/atomic-swap discipline) before this
landed — most directly the two ATOMIC tests (AC6).
"""

import fcntl
import os
import sqlite3
import struct
import sys
import time
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from web import corpus_manifest as M  # noqa: E402
from web import embeddings as E  # noqa: E402
from web import search_utils as SU  # noqa: E402

DAY = 86400.0


def _fake_embed(texts):
    """Fixed-size fake vectors — no Ollama round-trip, only shape matters here."""
    return [struct.pack(f"{E.EMBEDDING_DIM}f", *([0.01] * E.EMBEDDING_DIM))
            for _ in texts]


@pytest.fixture
def project(tmp_path, monkeypatch):
    """A scratch project root collect_files() can walk, isolated from the
    real 393k-chunk corpus — reindexing that inside a unit test would take
    hours, which is the exact failure this task exists to prevent."""
    monkeypatch.setattr(SU, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(E, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(E, "DB_PATH", tmp_path / "vec.db")
    monkeypatch.setattr(E, "_db", None)
    monkeypatch.setattr(E, "_db_opened_at", 0.0, raising=False)
    monkeypatch.setattr(E, "_embed", _fake_embed)

    (tmp_path / "alpha.md").write_text("# Alpha\n\nOriginal alpha content.\n")
    (tmp_path / "beta.md").write_text("# Beta\n\nOriginal beta content.\n")
    return tmp_path


# --------------------------------------------------------------------------
# Bootstrap: no index yet falls back to a full build
# --------------------------------------------------------------------------

def test_bootstrap_full_build_when_no_index_exists(project):
    stats = E.reindex_incremental()
    assert stats["mode"] == "bootstrap-full"
    assert stats["num_docs"] >= 2  # alpha.md, beta.md (+ 3 canaries)


# --------------------------------------------------------------------------
# INCREMENTAL — only the changed set is re-embedded (AC3)
# --------------------------------------------------------------------------

def test_incremental_only_reembeds_changed_files(project, monkeypatch):
    E.reindex_incremental()  # bootstrap

    calls = []
    real = E._embed

    def counting_embed(texts):
        calls.append(len(texts))
        return real(texts)

    monkeypatch.setattr(E, "_embed", counting_embed)

    (project / "alpha.md").write_text("# Alpha\n\nCHANGED alpha content.\n")
    (project / "gamma.md").write_text("# Gamma\n\nBrand new gamma content.\n")

    stats = E.reindex_incremental()

    assert stats["mode"] == "incremental"
    assert stats["files_changed"] == 2   # alpha (changed) + gamma (new)
    assert stats["files_removed"] == 0
    total_embedded = sum(calls)
    assert total_embedded < 20, (
        f"embedded {total_embedded} chunks for a 2-file change out of 3 files — "
        f"beta.md (untouched) appears to have been re-embedded too"
    )


def test_removed_file_drops_its_rows(project):
    E.reindex_incremental()
    (project / "beta.md").unlink()

    stats = E.reindex_incremental()
    assert stats["files_removed"] == 1

    db = E._get_db()
    rows = db.execute(
        "SELECT COUNT(*) FROM documents WHERE path = 'beta.md'").fetchone()[0]
    assert rows == 0
    fs = db.execute(
        "SELECT COUNT(*) FROM file_state WHERE path = 'beta.md'").fetchone()[0]
    assert fs == 0


def test_unchanged_file_content_is_not_rewritten(project):
    E.reindex_incremental()
    db = E._get_db()
    before = db.execute(
        "SELECT chunk_text FROM documents WHERE path = 'beta.md'").fetchone()[0]
    E._db = None

    E.reindex_incremental()
    db = E._get_db()
    after = db.execute(
        "SELECT chunk_text FROM documents WHERE path = 'beta.md'").fetchone()[0]
    assert before == after


# --------------------------------------------------------------------------
# ATOMIC — a run killed mid-way leaves the previous index serving (AC4, AC6)
# --------------------------------------------------------------------------

def test_a_run_killed_mid_way_does_not_advance_the_manifest(project, monkeypatch):
    E.reindex_incremental()  # bootstrap
    before_manifest = M.read_manifest(E.DB_PATH)
    before_bytes = E.DB_PATH.read_bytes()

    def boom(texts):
        raise RuntimeError("simulated embedder death mid-run")

    monkeypatch.setattr(E, "_embed", boom)
    (project / "alpha.md").write_text("# Alpha\n\nCHANGED, but the run dies.\n")

    with pytest.raises(RuntimeError):
        E.reindex_incremental()

    after_manifest = M.read_manifest(E.DB_PATH)
    assert after_manifest == before_manifest, (
        "manifest advanced despite the run dying before the swap"
    )
    assert E.DB_PATH.read_bytes() == before_bytes, (
        "database file changed despite the run dying before the swap"
    )
    tmp_path = E.DB_PATH.with_suffix(E.DB_PATH.suffix + ".reindex.tmp")
    assert not tmp_path.exists(), "crashed run left its working copy behind"


def test_a_killed_run_leaves_the_previous_index_still_serving(project, monkeypatch):
    E.reindex_incremental()
    E._db = None
    old_stats = E.index_stats()

    def boom(texts):
        raise RuntimeError("simulated embedder death mid-run")

    monkeypatch.setattr(E, "_embed", boom)
    (project / "alpha.md").write_text("# Alpha\n\nCHANGED, but the run dies.\n")
    with pytest.raises(RuntimeError):
        E.reindex_incremental()

    E._db = None
    E._db_opened_at = 0.0
    new_stats = E.index_stats()
    assert new_stats["index_built_at"] == old_stats["index_built_at"], (
        "reported build time moved despite the run dying before the swap"
    )
    db = E._get_db()
    text = db.execute(
        "SELECT chunk_text FROM documents WHERE path = 'alpha.md'").fetchone()[0]
    assert "CHANGED" not in text, "the half-run's content leaked into the live index"


# --------------------------------------------------------------------------
# FRESH — a successful run advances the freshness clock (AC1, AC5, AC6)
# --------------------------------------------------------------------------

def test_reindex_makes_a_stale_index_report_fresh(project):
    E.reindex_incremental()  # bootstrap
    stale = M.build_manifest(
        num_docs=2, num_chunks=5, model=E.MODEL_NAME, embedding_dim=E.EMBEDDING_DIM,
        max_chunk_chars=E.MAX_CHUNK_CHARS, embed_context_tokens=E.EMBED_CONTEXT_TOKENS,
        canary_token="FWCANARY-OLD", started_at=0.0, project_root=project,
    )
    stale["finished_at"] = time.time() - 30 * DAY
    M.write_manifest(E.DB_PATH, stale)

    before = E.index_freshness()
    assert before["age_seconds"] > 29 * DAY

    E.reindex_incremental()

    after = E.index_freshness()
    assert after["age_seconds"] < 60, (
        f"reindex ran but the reported age did not drop: {after}"
    )
    assert after["source"] == "manifest"


def test_reindex_writes_a_new_canary_token_each_run(project):
    first = E.reindex_incremental()
    second = E.reindex_incremental()
    assert first["canary_token"] != second["canary_token"], (
        "canary token unchanged across runs — corpus_health() cannot tell "
        "this run happened from the last one"
    )


# --------------------------------------------------------------------------
# The production state: an index that predates file_state entirely.
#
# Every test above builds its baseline through this module's own code, so
# file_state is always populated and always agrees with `documents`. The real
# index on disk was built in March by `build_index()` before slice 5 existed
# — it has 21,292 chunks over 1,380 paths and no file_state table at all.
# That is the state the first scheduled run will actually meet, and nothing
# above reaches it. Same class as T-3015: the modal input was never a fixture.
# --------------------------------------------------------------------------

def _drop_file_state(db_path):
    """Reduce an index built by this module to a pre-T-3014 one."""
    db = sqlite3.connect(str(db_path))
    db.execute("DROP TABLE IF EXISTS file_state")
    db.commit()
    db.close()


def test_legacy_index_still_purges_files_deleted_from_the_corpus(project):
    """Removal detection must read `documents`, not `file_state`.

    `file_state` is this module's own bookkeeping; `documents` is the record of
    what is actually indexed. When the two disagree — which is exactly what a
    pre-slice-5 index looks like — trusting the bookkeeping means deleted files
    keep their rows forever and search returns paths that do not exist.
    Measured on the live index: 35 such paths, all tasks that moved
    active/ -> completed/, so the stale copy sits alongside the fresh one.
    """
    E.reindex_incremental()
    _drop_file_state(E.DB_PATH)
    (project / "beta.md").unlink()

    E.reindex_incremental()

    db = sqlite3.connect(str(E.DB_PATH))
    rows = db.execute(
        "SELECT COUNT(*) FROM documents WHERE path = 'beta.md'").fetchone()[0]
    db.close()
    assert rows == 0, (
        "beta.md was deleted from the corpus but kept its rows: removal was "
        "computed from file_state, which a legacy index does not have"
    )


def test_legacy_index_does_not_report_a_full_reembed_as_incremental(project):
    """A run that re-embeds the whole corpus must not be labelled the cheap path.

    With no baseline every file reads as changed, so this run costs a full
    rebuild — hours on the real corpus. Reporting `mode: incremental` makes the
    expensive first run indistinguishable in the logs from the cheap steady
    state, which is the one number an operator would use to decide the schedule
    holds.
    """
    E.reindex_incremental()
    _drop_file_state(E.DB_PATH)

    stats = E.reindex_incremental()

    assert stats["mode"] != "incremental", (
        f"re-embedded every file but reported mode={stats['mode']!r}"
    )
    assert stats["files_changed"] == 2


def test_steady_state_still_reports_incremental(project):
    """Discriminating counterpart: the honest label must not swallow the real one."""
    E.reindex_incremental()
    (project / "alpha.md").write_text("# Alpha\n\nEdited.\n")
    stats = E.reindex_incremental()
    assert stats["mode"] == "incremental"
    assert stats["files_changed"] == 1


# --------------------------------------------------------------------------
# Concurrency. The cron line wraps this in flock, which serialises cron
# against cron and nothing else — a manual run, a second console, or any
# other importer of this module races it on a shared, predictable scratch
# path. Observed live during T-3014's first real bootstrap: the scratch file
# was unlinked out from under a 25-minute run, which went on embedding into
# an unlinked inode with no idea anything was wrong.
# --------------------------------------------------------------------------

def test_scratch_file_is_per_process(project):
    """A shared scratch name is what makes two runs able to destroy each other."""
    seen = {}
    real_copy = E.shutil.copy2

    def spy(src, dst):
        seen["dst"] = str(dst)
        return real_copy(src, dst)

    E.reindex_incremental()  # bootstrap so the next run takes the copy path
    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(E.shutil, "copy2", spy)
        E.reindex_incremental()

    assert str(os.getpid()) in seen["dst"], (
        f"scratch path {seen['dst']} is not per-process — a second run picks "
        "the same name and unlinks this one's working file"
    )


def test_a_second_run_is_refused_while_one_holds_the_lock(project):
    """Concurrency is owned by the function, not by the caller's flock."""
    E.reindex_incremental()

    lock_path = E.DB_PATH.with_suffix(E.DB_PATH.suffix + ".reindex.lock")
    fd = os.open(str(lock_path), os.O_CREAT | os.O_RDWR, 0o644)
    fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    try:
        stats = E.reindex_incremental()
    finally:
        fcntl.flock(fd, fcntl.LOCK_UN)
        os.close(fd)

    assert stats["mode"] == "skipped-locked", (
        f"a second concurrent reindex was allowed to run: {stats}"
    )


def test_lock_is_released_so_the_next_run_can_proceed(project):
    """Discriminating counterpart: 'always skipped' must not pass as success."""
    E.reindex_incremental()
    assert E.reindex_incremental()["mode"] != "skipped-locked"


def test_swap_is_refused_if_the_scratch_file_was_replaced(project):
    """The worst available outcome is publishing a stranger's database.

    If our scratch file is unlinked and recreated by something else, os.replace
    would install *that* file over the live index — silently, and with no way to
    tell afterwards. Staged on the canary flush, which is the last embed of the
    run: everything after it is reads and a close, so this isolates the identity
    guard instead of tripping sqlite mid-write.
    """
    E.reindex_incremental()
    (project / "alpha.md").write_text("# Alpha\n\nEdited so there is work to do.\n")

    live_before = E.DB_PATH.read_bytes()

    def sabotage_on_canary(texts):
        if any("FWCANARY-" in t for t in texts):
            for scratch in E.DB_PATH.parent.glob(E.DB_PATH.name + ".reindex.*.tmp"):
                os.unlink(scratch)
                with open(scratch, "wb") as fh:
                    fh.write(b"not the database this run built")
        return _fake_embed(texts)

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(E, "_embed", sabotage_on_canary)
        with pytest.raises(RuntimeError, match="refusing to swap"):
            E.reindex_incremental()

    assert E.DB_PATH.read_bytes() == live_before, (
        "the live index was modified by a run that should have refused to swap"
    )


# --------------------------------------------------------------------------
# Resumability. At 1.9 chunks/s (measured against the live embed host) the
# 394,230-chunk bootstrap is ~29-58h. Non-resumable, that never completes on
# an hourly cron: every firing restarts from zero and the canary stays unknown
# forever, while each individual run looks like it behaved correctly.
# --------------------------------------------------------------------------

def _fail_after(n_calls):
    """An embedder that dies partway, like a reboot or an OOM would."""
    state = {"n": 0}

    def embed(texts):
        state["n"] += 1
        if state["n"] > n_calls:
            raise RuntimeError("embed host went away mid-bootstrap")
        return _fake_embed(texts)

    return embed


def test_a_partial_run_parks_its_work_instead_of_discarding_it(project):
    E.reindex_incremental()
    for i in range(120):
        (project / f"f{i}.md").write_text(f"# File {i}\n\nBody {i}.\n")

    resume_path = E.DB_PATH.with_suffix(E.DB_PATH.suffix + ".reindex.resume")
    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(E, "_embed", _fail_after(1))
        with pytest.raises(RuntimeError):
            E.reindex_incremental()

    assert resume_path.exists(), (
        "a partial bootstrap threw its committed work away — the next cron "
        "firing restarts from zero and the schedule can never converge"
    )
    db = sqlite3.connect(str(resume_path))
    done = db.execute("SELECT COUNT(*) FROM file_state").fetchone()[0]
    db.close()
    assert done > 0, "resume file carries no completed files"


def test_the_next_run_resumes_and_does_not_redo_completed_files(project):
    E.reindex_incremental()
    for i in range(120):
        (project / f"f{i}.md").write_text(f"# File {i}\n\nBody {i}.\n")

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(E, "_embed", _fail_after(1))
        with pytest.raises(RuntimeError):
            E.reindex_incremental()

    resume_path = E.DB_PATH.with_suffix(E.DB_PATH.suffix + ".reindex.resume")
    db = sqlite3.connect(str(resume_path))
    done_first = db.execute("SELECT COUNT(*) FROM file_state").fetchone()[0]
    db.close()

    calls = {"n": 0}
    real = _fake_embed

    def counting(texts):
        calls["n"] += 1
        return real(texts)

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(E, "_embed", counting)
        stats = E.reindex_incremental()

    assert stats["files_changed"] < 121, (
        f"resumed run re-embedded everything ({stats['files_changed']} files) — "
        f"{done_first} were already done"
    )
    assert not resume_path.exists(), "resume file survived a completed run"


def test_a_completed_run_leaves_no_resume_file_behind(project):
    """Discriminating counterpart: parking must not become the normal exit."""
    E.reindex_incremental()
    (project / "alpha.md").write_text("# Alpha\n\nEdited.\n")
    E.reindex_incremental()
    resume_path = E.DB_PATH.with_suffix(E.DB_PATH.suffix + ".reindex.resume")
    assert not resume_path.exists()


def test_a_files_rows_and_its_file_state_land_together(project):
    """The resume skip is only correct if these two are never out of step.

    file_state says "this file is done". If it could commit while the file's
    chunk rows had not, a resumed run would skip a file it never actually
    embedded — and the gap would be invisible, because the bookkeeping says
    complete. Checkpoints therefore fall on file boundaries, never inside one.
    """
    E.reindex_incremental()
    for i in range(60):
        (project / f"g{i}.md").write_text(f"# G{i}\n\n" + ("body text. " * 200))

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(E, "_embed", _fail_after(3))
        with pytest.raises(RuntimeError):
            E.reindex_incremental()

    resume_path = E.DB_PATH.with_suffix(E.DB_PATH.suffix + ".reindex.resume")
    db = sqlite3.connect(str(resume_path))
    claimed = {r[0] for r in db.execute("SELECT path FROM file_state").fetchall()}
    have_rows = {r[0] for r in db.execute(
        "SELECT DISTINCT path FROM documents").fetchall()}
    db.close()

    orphaned = claimed - have_rows
    assert not orphaned, (
        f"{len(orphaned)} file(s) marked done in file_state with no chunk rows: "
        f"{sorted(orphaned)[:3]} — a resumed run would skip them forever"
    )
