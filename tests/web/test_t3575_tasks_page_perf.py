"""T-3575: /tasks cache is change-driven, and the board payload is capped."""

import os
import re
import time
from pathlib import Path

os.environ.setdefault("PROJECT_ROOT", str(Path(__file__).resolve().parents[2]))

from web import shared  # noqa: E402


def _write(path, name):
    path.write_text(f"---\nid: T-9001\nname: {name}\nstatus: captured\n---\nbody\n")


def _isolated(monkeypatch, tmp_path):
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    monkeypatch.setattr(shared, "PROJECT_ROOT", tmp_path)
    monkeypatch.setitem(shared._task_cache, "data", None)
    monkeypatch.setitem(shared._task_cache, "tags", None)
    shared._TASK_FM_CACHE.clear()
    shared._EPISODIC_TAGS_CACHE.clear()
    return tmp_path / ".tasks" / "active" / "T-9001-x.md"


def test_changed_task_file_reflected_on_next_call(monkeypatch, tmp_path):
    f = _isolated(monkeypatch, tmp_path)
    _write(f, "before")
    assert [t["name"] for t in shared.get_all_task_metadata()] == ["before"]
    _write(f, "after edit")
    st = f.stat()
    os.utime(f, ns=(st.st_atime_ns, st.st_mtime_ns + 5_000_000_000))  # mtime granularity guard
    assert [t["name"] for t in shared.get_all_task_metadata()] == ["after edit"]
    assert shared.get_task_names() == {"T-9001": "after edit"}


def test_new_and_removed_file_reflected(monkeypatch, tmp_path):
    f = _isolated(monkeypatch, tmp_path)
    _write(f, "one")
    assert len(shared.get_all_task_metadata()) == 1
    g = f.with_name("T-9002-y.md")
    g.write_text("---\nid: T-9002\nname: two\nstatus: captured\n---\n")
    assert len(shared.get_all_task_metadata()) == 2
    g.unlink()
    assert len(shared.get_all_task_metadata()) == 1


def test_unchanged_corpus_is_not_reparsed_after_ttl_old_ttl(monkeypatch, tmp_path):
    """Regression for the 30s TTL: a visit >30s later must be a cache hit."""
    f = _isolated(monkeypatch, tmp_path)
    _write(f, "steady")
    first = shared.get_all_task_metadata()
    monkeypatch.setitem(shared._task_cache, "ts", time.monotonic() - 120)  # 4x the old TTL
    assert shared.get_all_task_metadata() is first
    assert shared._TASK_CACHE_TTL >= 120


def test_episodic_tags_change_driven(monkeypatch, tmp_path):
    _isolated(monkeypatch, tmp_path)
    ep = tmp_path / ".context" / "episodic"
    ep.mkdir(parents=True)
    (ep / "T-9001.yaml").write_text("task_id: T-9001\ntags: [a]\n")
    assert shared.get_episodic_tags() == {"T-9001": ["a"]}
    (ep / "T-9001.yaml").write_text("task_id: T-9001\ntags: [a, b]\n")
    st = (ep / "T-9001.yaml").stat()
    os.utime(ep / "T-9001.yaml", ns=(st.st_atime_ns, st.st_mtime_ns + 5_000_000_000))
    assert shared.get_episodic_tags() == {"T-9001": ["a", "b"]}


def test_board_columns_capped_but_list_filter_reaches_everything():
    from web.app import app
    from web.blueprints.tasks import BOARD_COLUMN_CAP

    c = app.test_client()
    html = c.get("/tasks").get_data(as_text=True)
    cards = len(re.findall(r"<article class=\"kanban-card\"", html))
    columns = len(re.findall(r'class="kanban-column"', html))
    assert cards <= BOARD_COLUMN_CAP * columns
    counts = [int(n) for n in re.findall(r'class="count">\((\d+)\)', html)]
    if max(counts) > BOARD_COLUMN_CAP:
        assert "more &rarr;" in html  # overflow link present
        # the filter the overflow link targets still lists every task of that status
        big = counts.index(max(counts))
        status = re.findall(r'class="kanban-column" data-status="([^"]+)"', html)[big]
        lst = c.get(f"/tasks?view=list&status={status}").get_data(as_text=True)
        assert lst.count('data-bulk-select="T-') >= max(counts)
