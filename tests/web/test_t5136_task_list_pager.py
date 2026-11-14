"""T-5136: the task list view is paged, and every task stays reachable through the pager.

Before: /tasks?view=list rendered every task with four inline edit forms — 5,120 rows was
18.9 MB of HTML and 37 s before the browser showed the table.
"""

import os
import re
from pathlib import Path

os.environ.setdefault("PROJECT_ROOT", str(Path(__file__).resolve().parents[2]))

from web import shared  # noqa: E402
from web.app import app  # noqa: E402
from web.blueprints import tasks as tasks_bp  # noqa: E402

N = 11


def _corpus(monkeypatch, tmp_path):
    active = tmp_path / ".tasks" / "active"
    active.mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    for i in range(N):
        status = "captured" if i % 2 else "started-work"
        (active / f"T-{9100 + i}-x.md").write_text(
            f"---\nid: T-{9100 + i}\nname: task {i:02d}\nstatus: {status}\n"
            f"workflow_type: build\nowner: agent\nhorizon: now\n---\nbody\n")
    monkeypatch.setattr(shared, "PROJECT_ROOT", tmp_path)
    monkeypatch.setitem(shared._task_cache, "data", None)
    monkeypatch.setitem(shared._task_cache, "tags", None)
    shared._TASK_FM_CACHE.clear()
    shared._EPISODIC_TAGS_CACHE.clear()
    monkeypatch.setattr(tasks_bp, "LIST_PAGE_SIZE", 4)


def _ids(html):
    return re.findall(r'data-bulk-select="(T-\d+)"', html)


def _next(html):
    m = re.search(r'href="([^"]+)"[^>]*rel="next"', html)
    return m.group(1).replace("&amp;", "&") if m else None


def _walk(client, url):
    pages = []
    while url:
        html = client.get(url).get_data(as_text=True)
        pages.append(_ids(html))
        url = _next(html)
    return pages


def test_pages_cover_every_task_once(monkeypatch, tmp_path):
    _corpus(monkeypatch, tmp_path)
    pages = _walk(app.test_client(), "/tasks?view=list")
    assert [len(p) for p in pages] == [4, 4, 3]
    flat = [i for p in pages for i in p]
    assert sorted(flat) == sorted(f"T-{9100 + i}" for i in range(N))
    assert len(flat) == len(set(flat))


def test_pager_keeps_filter_and_sort(monkeypatch, tmp_path):
    _corpus(monkeypatch, tmp_path)
    client = app.test_client()
    pages = _walk(client, "/tasks?view=list&status=captured&sort=name")
    flat = [i for p in pages for i in p]
    want = [f"T-{9100 + i}" for i in range(N) if i % 2]  # captured, name order = id order here
    assert flat == want
    html = client.get("/tasks?view=list&status=captured&sort=name").get_data(as_text=True)
    nxt = _next(html)
    assert "status=captured" in nxt and "sort=name" in nxt and "page=2" in nxt


def test_count_and_position_shown(monkeypatch, tmp_path):
    _corpus(monkeypatch, tmp_path)
    html = app.test_client().get("/tasks?view=list&page=2").get_data(as_text=True)
    assert "Showing 5–8 of 11 (page 2 of 3)" in html
    assert 'rel="prev"' in html and 'rel="next"' in html


def test_out_of_range_page_is_clamped(monkeypatch, tmp_path):
    _corpus(monkeypatch, tmp_path)
    client = app.test_client()
    assert len(_ids(client.get("/tasks?view=list&page=99").get_data(as_text=True))) == 3
    assert len(_ids(client.get("/tasks?view=list&page=x").get_data(as_text=True))) == 4


def test_small_list_has_no_pager(monkeypatch, tmp_path):
    _corpus(monkeypatch, tmp_path)
    monkeypatch.setattr(tasks_bp, "LIST_PAGE_SIZE", 200)
    html = app.test_client().get("/tasks?view=list").get_data(as_text=True)
    assert len(_ids(html)) == N
    assert "wt-list-pager" not in html
