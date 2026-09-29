"""T-3564: arc detail page order — quick links, Purpose, Task overview, story, BVP.

Runs against the real arc store (continuous-run has the T-3563 story fields) and,
for the no-story case, a temp arc registered by monkeypatching `_read_arc`.
"""

import re
import sys

import pytest

sys.path.insert(0, ".")


@pytest.fixture()
def client():
    from web.app import app

    app.config["TESTING"] = True
    return app.test_client()


def _ids(html):
    return set(re.findall(r'<section[^>]*\sid="([^"]+)"', html))


def _links(html):
    nav = re.search(r'<nav class="arc-quicklinks".*?</nav>', html, re.S)
    assert nav, "quick-link bar missing"
    return nav.group(0), re.findall(r'href="#([^"]+)"', nav.group(0))


def test_story_arc_layout(client):
    html = client.get("/arcs/continuous-run").get_data(as_text=True)
    nav, targets = _links(html)
    assert targets
    all_ids = set(re.findall(r'\sid="([^"]+)"', html))
    for t in targets:
        assert t in all_ids, f"dead quick link #{t}"
    # every rendered section is linked
    for sid in _ids(html):
        assert sid in targets, f"section #{sid} has no quick link"
    # quick links are the first element under the title
    assert html.index('class="arc-quicklinks"') < html.index('id="purpose"')
    assert "hx-" not in nav
    for sid in ("purpose", "task-overview", "success-criteria", "decisions",
                "open-questions", "non-goals", "history", "evidence"):
        assert sid in targets
    # order
    assert html.index('id="purpose"') < html.index('id="task-overview"')
    assert html.index('id="task-overview"') < html.index('id="bvp-signals"')
    assert html.index('id="task-overview"') < html.index('id="constituent-tasks"')
    assert "done" in html[html.index('id="task-overview"'):html.index('id="success-criteria"')]


def test_arc_without_story_fields(client, monkeypatch):
    from web.blueprints import arcs

    real = arcs._read_arc("continuous-run")
    bare = {k: v for k, v in real.items()
            if k not in ("purpose", "objective", "success_criteria", "context", "decisions",
                         "open_questions", "non_goals", "history", "evidence", "story_review")}
    monkeypatch.setattr(arcs, "_read_arc", lambda _id: dict(bare))
    html = client.get("/arcs/continuous-run").get_data(as_text=True)
    _, targets = _links(html)
    assert "purpose" not in targets and 'id="purpose"' not in html
    for sid in ("success-criteria", "context", "decisions", "open-questions",
                "non-goals", "history", "evidence"):
        assert sid not in targets
        assert f'id="{sid}"' not in html
    assert "task-overview" in targets
    all_ids = set(re.findall(r'\sid="([^"]+)"', html))
    for t in targets:
        assert t in all_ids
    for sid in _ids(html):
        assert sid in targets


def _c(tid, status, completed=False):
    return {"id": tid, "name": f"n {tid}", "status": status, "completed": completed}


def test_task_overview_awaiting_review_and_open_order():
    from web.blueprints import arcs

    ov = arcs._task_overview([
        _c("T-1", "captured"), _c("T-2", "issues"), _c("T-3", "started-work"),
        _c("T-4", "work-completed"), _c("T-5", "work-completed", completed=True),
    ])
    assert [c["id"] for c in ov["open_tasks"]] == ["T-2", "T-3", "T-1"]
    assert [c["id"] for c in ov["awaiting_review"]] == ["T-4"]
    labels = dict(ov["counts"])
    assert labels["awaiting review"] == 1 and labels["done"] == 1


def test_task_overview_render_awaiting_and_cap(client, monkeypatch):
    from web.blueprints import arcs

    real = arcs._resolve_constituents
    fake = ([_c("T-9001", "work-completed")]
            + [_c(f"T-91{i:02d}", "captured") for i in range(13)])
    for c in fake:
        c.update({"missing": False, "bvp": None})
    monkeypatch.setattr(arcs, "_resolve_constituents", lambda _a: [dict(c) for c in fake])
    html = client.get("/arcs/continuous-run").get_data(as_text=True)
    ov = html[html.index('id="task-overview"'):html.index('id="success-criteria"')]
    assert "awaiting review" in ov
    open_part = ov[ov.index("Open tasks"):ov.index("Awaiting human review")]
    assert "T-9001" not in open_part
    assert "+3 more" in open_part
    assert real  # keep reference to silence unused-name lint


def test_source_ref_links_task_file_paths():
    from web.blueprints import arcs

    ref = arcs._source_ref(".tasks/completed/T-2719-some-name.md#context")
    assert ref["href"] == "/tasks/T-2719"
    assert ref["text"] == ".tasks/completed/T-2719-some-name.md#context"
    assert arcs._source_ref(".context/foo.yaml")["href"] == ""


def test_scoped_drivers_anchor_and_purpose_headline(client):
    from web.blueprints import arcs

    secs = arcs._arc_sections({}, {"purpose": "", "objective": "", **{k: [] for k in (
        "success_criteria", "context", "decisions", "open_questions", "non_goals",
        "history", "evidence")}}, [], [], {"scoped_drivers": [{"name": "x"}]})
    assert {"id": "scoped-drivers", "title": "Scoped drivers"} in secs
    html = client.get("/arcs/continuous-run").get_data(as_text=True)
    assert "<blockquote><strong>" in html
    assert "Jump to:" in html
