"""T-5198: whole-corpus task metadata re-parses only the files that changed.

Per-file frontmatter is cached on (path, mtime_ns, size). A rebuild re-parses added and
changed files only, and drops removed ones from the per-file cache. The result (shape,
values, ordering) must equal a full parse with every cache cleared, after each kind of
change: edits (including a same-mtime, different-size rewrite), adds, deletes, a move
active -> completed, and a file whose frontmatter becomes invalid.
"""

import os
from pathlib import Path

import pytest

os.environ.setdefault("PROJECT_ROOT", str(Path(__file__).resolve().parents[2]))

from web import shared  # noqa: E402


def _write(d, n, *, name=None, extra="", wf="build"):
    p = d / f"T-{n}-x.md"
    p.write_text(f"---\nid: T-{n}\nname: {name or f'task {n}'}\nstatus: captured\n"
                 f"workflow_type: {wf}\n{extra}---\nbody {n}\n")
    return p


@pytest.fixture
def corpus(tmp_path, monkeypatch):
    active = tmp_path / ".tasks" / "active"
    completed = tmp_path / ".tasks" / "completed"
    active.mkdir(parents=True)
    completed.mkdir(parents=True)
    for n in (9001, 9010, 9100, 999, 12000):
        _write(active, n)
    for n in (8001, 8500, 10):
        _write(completed, n)
    (active / "T-Test-001-sentinel.md").write_text("---\nid: T-Test-001\nname: s\n---\n")
    (active / "T-9200-nofm.md").write_text("no frontmatter\n")
    monkeypatch.setattr(shared, "PROJECT_ROOT", tmp_path)
    monkeypatch.setitem(shared._task_cache, "data", None)
    shared._TASK_FM_CACHE.clear()
    return active, completed


@pytest.fixture
def parses(monkeypatch):
    seen = []
    real = shared._parse_task_fm_file
    monkeypatch.setattr(shared, "_parse_task_fm_file",
                        lambda p: seen.append(Path(p).name) or real(p))
    return seen


def _incremental():
    shared._task_cache["data"] = None          # force a rebuild, keep the per-file cache
    return shared.get_all_task_metadata()


def _full():
    saved = dict(shared._TASK_FM_CACHE)
    shared._TASK_FM_CACHE.clear()
    shared._task_cache["data"] = None
    try:
        return shared.get_all_task_metadata()
    finally:
        shared._TASK_FM_CACHE.clear()
        shared._TASK_FM_CACHE.update(saved)
        shared._task_cache["data"] = None


def _check(expected_parsed, parses):
    parses.clear()
    inc = _incremental()
    assert sorted(parses) == sorted(expected_parsed)
    full = _full()
    assert inc == full
    assert [t["id"] for t in inc] == [t["id"] for t in full]
    return inc


def test_cold_build_parses_everything_once_and_orders_as_before(corpus, parses):
    rows = _check([p.name for d in corpus for p in d.glob("T-*.md")
                   if not p.name.startswith("T-Test-")], parses)
    assert [t["id"] for t in rows] == ["T-999", "T-9001", "T-9010", "T-9100", "T-12000",
                                       "T-10", "T-8001", "T-8500"]
    assert {t["_location"] for t in rows[:5]} == {"active"}
    assert all(t["_path"].endswith(".md") for t in rows)
    assert shared.get_task_names()["T-9001"] == "task 9001"


def test_warm_rebuild_parses_nothing(corpus, parses):
    _incremental()
    _check([], parses)


def test_edit_add_delete_move_invalid(corpus, parses):
    active, completed = corpus
    _incremental()

    p = _write(active, 9010, name="renamed")                      # edit
    _check([p.name], parses)

    st = p.stat()                                                 # same mtime, new size
    p.write_text(p.read_text().replace("renamed", "renamed again, longer"))
    os.utime(p, ns=(st.st_atime_ns, st.st_mtime_ns))
    rows = _check([p.name], parses)
    assert next(t for t in rows if t["id"] == "T-9010")["name"] == "renamed again, longer"

    added = _write(active, 9300, wf="inception")                  # add
    _check([added.name], parses)

    gone = active / "T-9100-x.md"                                 # delete
    gone.unlink()
    rows = _check([], parses)
    assert "T-9100" not in {t["id"] for t in rows}
    assert str(gone) not in shared._TASK_FM_CACHE

    moved = active / "T-9001-x.md"                                # move active -> completed
    dest = completed / moved.name
    moved.rename(dest)
    rows = _check([dest.name], parses)                            # new path = new key
    assert str(moved) not in shared._TASK_FM_CACHE
    assert next(t for t in rows if t["id"] == "T-9001")["_location"] == "completed"

    bad = active / "T-999-x.md"                                   # frontmatter turns invalid
    bad.write_text("---\nid: [unclosed\n---\nbody\n")
    rows = _check([bad.name], parses)
    assert "T-999" not in {t["id"] for t in rows}


def test_returned_rows_do_not_mutate_the_per_file_cache(corpus):
    rows = _incremental()
    rows[0]["name"] = "mutated"
    rows[0]["extra"] = 1
    assert _incremental() == _full()
