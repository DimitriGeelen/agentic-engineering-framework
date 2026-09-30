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
    # only backlog/archive columns are capped now; the rest show everything
    assert cards <= sum(counts_by_status(html, BOARD_COLUMN_CAP).values())
    counts = [int(n) for n in re.findall(r'class="count">\((\d+)\)', html)]
    if max(counts) > BOARD_COLUMN_CAP:
        assert "more &rarr;" in html  # overflow link present
        # the filter the overflow link targets still lists every task of that status
        big = counts.index(max(counts))
        status = re.findall(r'class="kanban-column" data-status="([^"]+)"', html)[big]
        lst = c.get(f"/tasks?view=list&status={status}").get_data(as_text=True)
        assert lst.count('data-bulk-select="T-') >= max(counts)


def counts_by_status(html, cap):
    """{status: max cards the board may show} - capped columns at the cap, others uncapped."""
    from web.blueprints.tasks import BOARD_CAPPED_STATUSES
    out = {}
    for status, n in re.findall(
            r'data-status="([^"]+)">\s*<div class="kanban-column-header">.*?class="count">\((\d+)\)',
            html, re.S):
        out[status] = min(int(n), cap) if status in BOARD_CAPPED_STATUSES else int(n)
    return out


def _seed(monkeypatch, tmp_path, n_started=30, n_captured=25):
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    (tmp_path / ".context" / "episodic").mkdir(parents=True)
    monkeypatch.setattr(shared, "PROJECT_ROOT", tmp_path)
    monkeypatch.setitem(shared._task_cache, "data", None)
    monkeypatch.setitem(shared._task_cache, "tags", None)
    shared._TASK_FM_CACHE.clear()
    shared._EPISODIC_TAGS_CACHE.clear()
    # ids and last_update ascend together, but the OLDEST ids are the stalest work
    for i in range(1, n_started + 1):
        (tmp_path / ".tasks" / "active" / f"T-{100 + i}-s.md").write_text(
            f"---\nid: T-{100 + i}\nname: started{i}\nstatus: started-work\nowner: agent\n"
            f"last_update: 2026-09-{i:02d}T00:00:00Z\n---\n")
    for i in range(1, n_captured + 1):
        (tmp_path / ".tasks" / "active" / f"T-{500 + i}-c.md").write_text(
            f"---\nid: T-{500 + i}\nname: captured{i}\nstatus: captured\nowner: human\n"
            f"last_update: 2026-08-{i:02d}T00:00:00Z\n---\n")


def test_board_shows_current_work_newest_first(monkeypatch, tmp_path):
    from web.app import app
    from web.blueprints.tasks import BOARD_COLUMN_CAP
    _seed(monkeypatch, tmp_path)
    html = app.test_client().get("/tasks").get_data(as_text=True)
    # In Progress is uncapped: the most recent started-work task AND the oldest are on the board
    assert 'data-task-id="T-130"' in html and 'data-task-id="T-101"' in html
    # Captured is capped at BOARD_COLUMN_CAP, trimming the STALEST cards, not the newest
    assert 'data-task-id="T-525"' in html
    assert 'data-task-id="T-501"' not in html
    assert len(re.findall(r'data-task-id="T-5\d\d"', html)) == BOARD_COLUMN_CAP
    # newest-first inside a column
    assert html.index('data-task-id="T-130"') < html.index('data-task-id="T-129"')


def test_overflow_link_preserves_active_filters(monkeypatch, tmp_path):
    from web.app import app
    _seed(monkeypatch, tmp_path)
    html = app.test_client().get("/tasks?owner=human&q=captured&sort=name").get_data(as_text=True)
    m = re.search(r'<a href="(/tasks\?view=list[^"]*)"[^>]*>\s*\+\d+ more', html.replace("&amp;", "&"))
    assert m, "overflow link missing"
    href = m.group(1)
    for frag in ("status=captured", "owner=human", "q=captured", "sort=name"):
        assert frag in href, (frag, href)


def test_task_signature_computed_once_per_request(monkeypatch, tmp_path):
    from web.app import app
    _isolated(monkeypatch, tmp_path)
    calls = []
    real = shared._dir_signature
    monkeypatch.setattr(shared, "_dir_signature", lambda *a, **k: calls.append(a) or real(*a, **k))
    with app.test_request_context("/arcs/x"):
        for _ in range(50):
            shared.get_all_task_metadata()
        assert len(calls) == 2  # active + completed, once
    with app.test_request_context("/arcs/x"):
        shared.get_all_task_metadata()
    assert len(calls) == 4  # a new request re-stats
    with app.test_request_context("/arcs/x", method="POST"):
        shared.get_all_task_metadata()
        shared.get_all_task_metadata()
    assert len(calls) == 8  # mutating requests are never memoised
